using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Net;
using System.Globalization;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Model.Constants;
using EasyPark.Services.Database;
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;
using ReservationModel = EasyPark.Model.Models.Reservation;
using ReservationDb = EasyPark.Services.Database.Reservation;
using IReservationHistoryService = EasyPark.Services.Interfaces.IReservationHistoryService;
using EasyPark.Model.Messages;

namespace EasyPark.Services.Services
{
    public class ReservationService : BaseCRUDService<ReservationModel, ReservationSearchObject, ReservationDb, ReservationInsertRequest, ReservationUpdateRequest>, IReservationService
    {
        private const string StatusPending = "Pending";
        private const string StatusConfirmed = "Confirmed";
        private const string StatusCompleted = "Completed";
        private const string StatusCancelled = "Cancelled";
        private const string StatusExpired = "Expired";
        private const string LegacyStatusActive = "Active";
        private static readonly TimeSpan RefundCutoffWindow = TimeSpan.FromHours(1);

        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IReservationHistoryService _historyService;
        private readonly IRabbitMQService _rabbitMQService;
        private readonly INotificationService _notificationService;

        public ReservationService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor, IReservationHistoryService historyService, IRabbitMQService rabbitMQService, INotificationService notificationService) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
            _historyService = historyService;
            _rabbitMQService = rabbitMQService;
            _notificationService = notificationService;
        }

        public override IQueryable<ReservationDb> AddFilter(ReservationSearchObject search, IQueryable<ReservationDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery
                .Include(r => r.User)
                .Include(r => r.ParkingSpot)
                    .ThenInclude(ps => ps.ParkingLocation);

            if (search.ParkingSpotId.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.ParkingSpotId == search.ParkingSpotId.Value);
            }

            if (search.ParkingLocationId.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.ParkingSpot.ParkingLocationId == search.ParkingLocationId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.Status))
            {
                var normalizedSearchStatus = NormalizeStatus(search.Status);
                if (normalizedSearchStatus == StatusConfirmed)
                {
                    filteredQuery = filteredQuery.Where(r => r.Status == StatusConfirmed || r.Status == LegacyStatusActive);
                }
                else
                {
                    filteredQuery = filteredQuery.Where(r => r.Status == normalizedSearchStatus);
                }
            }

            if (search.StartTimeFrom.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.StartTime >= search.StartTimeFrom.Value);
            }

            if (search.StartTimeTo.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.StartTime <= search.StartTimeTo.Value);
            }

            if (search.EndTimeFrom.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.EndTime >= search.EndTimeFrom.Value);
            }

            if (search.EndTimeTo.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.EndTime <= search.EndTimeTo.Value);
            }

            if (search.CancellationAllowed.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.CancellationAllowed == search.CancellationAllowed.Value);
            }

            if (CurrentUserHelper.IsAdmin(_httpContextAccessor) && search.UserId.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.UserId == search.UserId.Value);
            }
            else if (!CurrentUserHelper.IsAdmin(_httpContextAccessor))
            {
                var uid = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
                filteredQuery = filteredQuery.Where(r => r.UserId == uid);
            }

            filteredQuery = filteredQuery.OrderByDescending(r => r.CreatedAt);

            return filteredQuery;
        }

        public override void BeforeInsert(ReservationInsertRequest request, ReservationDb entity)
        {
            if (request.EndTime <= request.StartTime)
                throw new UserException("End time must be after start time", HttpStatusCode.BadRequest);

            if (request.StartTime < DateTime.UtcNow)
                throw new UserException("Start time cannot be in the past", HttpStatusCode.BadRequest);

            Database.ParkingSpot? parkingSpot = null;

            if (request.ParkingSpotId.HasValue)
            {
                parkingSpot = Context.ParkingSpots
                    .Include(ps => ps.ParkingLocation)
                    .FirstOrDefault(ps => ps.Id == request.ParkingSpotId.Value)
                    ?? throw new UserException("Parking spot not found", HttpStatusCode.NotFound);

                if (!parkingSpot.IsActive)
                    throw new UserException("Parking spot is not active", HttpStatusCode.BadRequest);

                bool isTaken = Context.Reservations.Any(r =>
                    r.ParkingSpotId == parkingSpot.Id &&
                    r.Status != StatusCancelled && r.Status != StatusExpired &&
                    r.StartTime < request.EndTime && r.EndTime > request.StartTime);

                if (isTaken)
                    throw new UserException($"Parking spot {parkingSpot.SpotNumber} is already reserved for this time period.", HttpStatusCode.BadRequest);
            }
            else
            {
                if (string.IsNullOrWhiteSpace(request.SpotType))
                    throw new UserException("SpotType is required when no ParkingSpotId is provided.", HttpStatusCode.BadRequest);

                if (!request.ParkingLocationId.HasValue)
                    throw new UserException("ParkingLocationId is required when no ParkingSpotId is provided.", HttpStatusCode.BadRequest);

                var candidates = Context.ParkingSpots
                    .Include(ps => ps.ParkingLocation)
                    .Where(ps =>
                        ps.ParkingLocationId == request.ParkingLocationId.Value &&
                        ps.SpotType == request.SpotType &&
                        ps.IsActive)
                    .ToList();

                if (!candidates.Any())
                    throw new UserException($"No active {request.SpotType} spots exist at this location.", HttpStatusCode.BadRequest);

                foreach (var spot in candidates)
                {
                    bool hasConflict = Context.Reservations.Any(r =>
                        r.ParkingSpotId == spot.Id &&
                        r.Status != StatusCancelled &&
                        r.Status != StatusExpired &&
                        r.StartTime < request.EndTime &&
                        r.EndTime > request.StartTime);

                    if (!hasConflict)
                    {
                        parkingSpot = spot;
                        break; // Found an available spot, reservation confirmed for this spot
                    }
                }

                if (parkingSpot == null)
                {
                    throw new UserException(
                        $"All {request.SpotType} spots are reserved for the selected time period. " +
                        "Please choose a different time.",
                        HttpStatusCode.BadRequest);
                }
            }

            entity.ParkingSpotId = parkingSpot.Id;
            EnsureWithinOperatingHours(parkingSpot.ParkingLocation, request.StartTime, request.EndTime);

            var duration = request.EndTime - request.StartTime;
            var hours = (decimal)duration.TotalHours;

            decimal pricePerHour = request.SpotType switch
            {
                "Disabled" when parkingSpot.ParkingLocation.PriceDisabled > 0
                    => parkingSpot.ParkingLocation.PriceDisabled,
                "Electric" when parkingSpot.ParkingLocation.PriceElectric > 0
                    => parkingSpot.ParkingLocation.PriceElectric,
                "Covered" when parkingSpot.ParkingLocation.PriceCovered > 0
                    => parkingSpot.ParkingLocation.PriceCovered,
                _ => parkingSpot.ParkingLocation.PriceRegular > 0
                    ? parkingSpot.ParkingLocation.PriceRegular
                    : parkingSpot.ParkingLocation.PricePerHour,
            };

            var totalPrice = hours * pricePerHour;

            entity.UserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            var user = Context.Users.Find(entity.UserId)
                ?? throw new UserException("User not found", HttpStatusCode.NotFound);

            if (user.Coins < totalPrice)
                throw new UserException(
                    $"Insufficient balance. Required: {totalPrice:F2} Coins. Have: {user.Coins:F2} Coins.",
                    HttpStatusCode.BadRequest);

            user.Coins -= totalPrice;

            entity.Status = StatusPending;
            entity.TotalPrice = totalPrice;
            entity.CreatedAt = DateTime.UtcNow;
            entity.CancellationAllowed = request.CancellationAllowed;
            entity.QRCode = GenerateQRCode(entity);
        }

        public override ReservationModel Insert(ReservationInsertRequest request)
        {
            var result = base.Insert(request);
            _historyService.LogStatusChange(result.Id, null, "Pending", "Reservation created");
            
            var reservation = GetById(result.Id);
            var user = Context.Users.Find(reservation.UserId);
            var parkingSpot = Context.ParkingSpots
                .Include(ps => ps.ParkingLocation)
                .FirstOrDefault(ps => ps.Id == reservation.ParkingSpotId);

            if (user != null && parkingSpot != null)
            {
                var message = new ReservationCreated
                {
                    ReservationId = reservation.Id,
                    Email = user.Email,
                    Name = $"{user.FirstName} {user.LastName}",
                    ParkingLocationName = parkingSpot.ParkingLocation.Name,
                    SpotNumber = parkingSpot.SpotNumber,
                    StartTime = reservation.StartTime,
                    EndTime = reservation.EndTime,
                    TotalPrice = reservation.TotalPrice,
                    QRCode = reservation.QRCode ?? ""
                };
                _rabbitMQService.PublishMessage("easypark_reservation_created", message);

                _notificationService.CreateNotification(
                    reservation.UserId,
                    "Reservation Created",
                    $"Your reservation at {parkingSpot.ParkingLocation.Name} on {reservation.StartTime:g} has been created.",
                    "Info");
            }

            return result;
        }

        public override void BeforeUpdate(ReservationUpdateRequest request, ReservationDb entity)
        {
            if (entity == null)
            {
                throw new UserException("Reservation not found", HttpStatusCode.NotFound);
            }

            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                entity.UserId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
            {
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            }

            var normalizedCurrentStatus = NormalizeStatus(entity.Status);
            var normalizedRequestedStatus = string.IsNullOrWhiteSpace(request.Status)
                ? null
                : NormalizeStatus(request.Status);

            var startTime = request.StartTime ?? entity.StartTime;
            var endTime = request.EndTime ?? entity.EndTime;

            if (endTime <= startTime)
            {
                throw new UserException("End time must be after start time", HttpStatusCode.BadRequest);
            }

            if (request.StartTime.HasValue || request.EndTime.HasValue)
            {
                var overlappingReservation = Context.Reservations
                    .Any(r => r.Id != entity.Id &&
                               r.ParkingSpotId == entity.ParkingSpotId &&
                               r.Status != StatusCancelled &&
                               r.Status != StatusExpired &&
                               r.EndTime > DateTime.UtcNow &&
                               r.StartTime < endTime && r.EndTime > startTime);

                if (overlappingReservation)
                {
                    throw new UserException("Parking spot is already reserved for this time period", HttpStatusCode.BadRequest);
                }

                var parkingSpot = Context.ParkingSpots
                    .Include(ps => ps.ParkingLocation)
                    .FirstOrDefault(ps => ps.Id == entity.ParkingSpotId);
                if (parkingSpot?.ParkingLocation != null)
                {
                    EnsureWithinOperatingHours(parkingSpot.ParkingLocation, startTime, endTime);
                }
            }

            entity.UpdatedAt = DateTime.UtcNow;

            if (normalizedRequestedStatus != null && normalizedRequestedStatus != normalizedCurrentStatus)
            {
                EnsureTransitionAllowed(normalizedCurrentStatus, normalizedRequestedStatus);

                if (normalizedRequestedStatus == StatusCancelled && !entity.CancellationAllowed)
                {
                    throw new UserException("Cancellation is not allowed for this reservation", HttpStatusCode.BadRequest);
                }

                var cancellationReason = request.CancellationReason;
                if (normalizedRequestedStatus == StatusCancelled && string.IsNullOrWhiteSpace(cancellationReason))
                {
                    cancellationReason = CurrentUserHelper.IsAdmin(_httpContextAccessor)
                        ? "Cancelled by admin"
                        : "Cancelled by user";
                }

                var oldStatus = normalizedCurrentStatus;
                entity.Status = normalizedRequestedStatus;
                _historyService.LogStatusChange(entity.Id, oldStatus, normalizedRequestedStatus, cancellationReason);

                var refundMessage = normalizedRequestedStatus == StatusCancelled
                    ? TryApplyCancellationRefund(entity)
                    : null;

                var reservation = GetById(entity.Id);
                var user = Context.Users.Find(reservation.UserId);
                var parkingSpot = Context.ParkingSpots
                    .Include(ps => ps.ParkingLocation)
                    .FirstOrDefault(ps => ps.Id == reservation.ParkingSpotId);

                if (user != null && parkingSpot != null)
                {
                    if (normalizedRequestedStatus == StatusCancelled)
                    {
                        var finalCancellationReason = string.IsNullOrWhiteSpace(refundMessage)
                            ? cancellationReason
                            : $"{cancellationReason}. {refundMessage}";

                        var cancelledMessage = new ReservationCancelled
                        {
                            ReservationId = reservation.Id,
                            Email = user.Email,
                            Name = $"{user.FirstName} {user.LastName}",
                            ParkingLocationName = parkingSpot.ParkingLocation.Name,
                            SpotNumber = parkingSpot.SpotNumber,
                            StartTime = reservation.StartTime,
                            EndTime = reservation.EndTime,
                            TotalPrice = reservation.TotalPrice,
                            CancellationReason = finalCancellationReason
                        };
                        _rabbitMQService.PublishMessage("easypark_reservation_cancelled", cancelledMessage);

                        _notificationService.CreateNotification(
                            reservation.UserId,
                            "Reservation Cancelled",
                            $"Your reservation at {parkingSpot.ParkingLocation.Name} has been cancelled. Reason: {finalCancellationReason}",
                            "Alert");
                    }
                    else if (normalizedRequestedStatus == StatusCompleted)
                    {
                        var completedMessage = new ReservationCompleted
                        {
                            ReservationId = reservation.Id,
                            Email = user.Email,
                            Name = $"{user.FirstName} {user.LastName}",
                            ParkingLocationName = parkingSpot.ParkingLocation.Name,
                            SpotNumber = parkingSpot.SpotNumber,
                            StartTime = reservation.StartTime,
                            EndTime = reservation.EndTime,
                            TotalPrice = reservation.TotalPrice
                        };
                        _rabbitMQService.PublishMessage("easypark_reservation_completed", completedMessage);

                        _notificationService.CreateNotification(
                            reservation.UserId,
                            "Reservation Completed",
                            $"Your reservation at {parkingSpot.ParkingLocation.Name} has been completed.",
                            "Success");
                    }
                    else if (normalizedRequestedStatus == StatusConfirmed)
                    {
                        _notificationService.CreateNotification(
                            reservation.UserId,
                            "Reservation Confirmed",
                            $"Your reservation at {parkingSpot.ParkingLocation.Name} on {reservation.StartTime:g} has been confirmed.",
                            "Success");
                    }
                }
            }
        }

        public override ReservationModel GetById(int id)
        {
            var entity = Context.Set<ReservationDb>()
                .Include(r => r.User)
                .Include(r => r.ParkingSpot)
                    .ThenInclude(ps => ps.ParkingLocation)
                .FirstOrDefault(r => r.Id == id);

            if (entity == null)
            {
                throw new UserException("Reservation not found", HttpStatusCode.NotFound);
            }

            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                entity.UserId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
            {
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            }

            var model = Mapper.Map<ReservationModel>(entity);
            PopulateNavigationFields(entity, model);
            return model;
        }

        public override PagedResult<ReservationModel> GetPaged(ReservationSearchObject search)
        {
            var query = Context.Set<ReservationDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();
            var result = Mapper.Map<List<ReservationModel>>(list);

            for (int i = 0; i < list.Count; i++)
            {
                PopulateNavigationFields(list[i], result[i]);
            }

            return new PagedResult<ReservationModel>
            {
                ResultList = result,
                Count = count
            };
        }

        private static void PopulateNavigationFields(ReservationDb entity, ReservationModel model)
        {
            model.Status = NormalizeStatus(model.Status);

            if (entity.User != null)
                model.UserFullName = $"{entity.User.FirstName} {entity.User.LastName}";

            if (entity.ParkingSpot != null)
            {
                model.ParkingSpotNumber = entity.ParkingSpot.SpotNumber;
                model.SpotType = entity.ParkingSpot.SpotType;
                model.ParkingLocationId = entity.ParkingSpot.ParkingLocationId;

                if (entity.ParkingSpot.ParkingLocation != null)
                    model.ParkingLocationName = entity.ParkingSpot.ParkingLocation.Name;
            }
        }

        private string GenerateQRCode(ReservationDb reservation)
        {
            var qrData = new
            {
                reservationId = reservation.Id,
                parkingSpotId = reservation.ParkingSpotId,
                startTime = reservation.StartTime.ToString("o"),
                userId = reservation.UserId
            };
            return System.Text.Json.JsonSerializer.Serialize(qrData);
        }

        public Model.Models.Reservation ConfirmReservation(int id)
        {
            var entity = Context.Reservations
                .Include(r => r.ParkingSpot)
                    .ThenInclude(ps => ps.ParkingLocation)
                .FirstOrDefault(r => r.Id == id);

            if (entity == null)
                throw new UserException("Reservation not found", HttpStatusCode.NotFound);

            var currentStatus = NormalizeStatus(entity.Status);
            EnsureTransitionAllowed(currentStatus, StatusConfirmed);

            var oldStatus = currentStatus;
            entity.Status = StatusConfirmed;
            entity.UpdatedAt = DateTime.UtcNow;
            Context.SaveChanges();

            _historyService.LogStatusChange(entity.Id, oldStatus, StatusConfirmed, "Confirmed via QR scan");

            var confirmedReservation = GetById(entity.Id);
            var confirmedUser = Context.Users.Find(confirmedReservation.UserId);
            var confirmedSpot = Context.ParkingSpots
                .Include(ps => ps.ParkingLocation)
                .FirstOrDefault(ps => ps.Id == confirmedReservation.ParkingSpotId);

            if (confirmedUser != null && confirmedSpot != null)
            {
                _notificationService.CreateNotification(
                    confirmedReservation.UserId,
                    "Reservation Confirmed",
                    $"Your reservation at {confirmedSpot.ParkingLocation.Name} on {confirmedReservation.StartTime:g} has been confirmed.",
                    "Success");
            }

            return confirmedReservation;
        }

        public override void Delete(int id)
        {
            throw new BusinessException(
                "Reservations cannot be deleted. Use cancellation instead.",
                HttpStatusCode.MethodNotAllowed);
        }

        private static string NormalizeStatus(string status)
        {
            if (string.IsNullOrWhiteSpace(status))
            {
                throw new UserException("Status is required", HttpStatusCode.BadRequest);
            }

            return status.Trim() switch
            {
                LegacyStatusActive => StatusConfirmed,
                StatusPending => StatusPending,
                StatusConfirmed => StatusConfirmed,
                StatusCompleted => StatusCompleted,
                StatusCancelled => StatusCancelled,
                StatusExpired => StatusExpired,
                _ => throw new UserException(
                    $"Invalid status. Valid statuses are: {StatusPending}, {StatusConfirmed}, {StatusCompleted}, {StatusCancelled}, {StatusExpired}",
                    HttpStatusCode.BadRequest)
            };
        }

        private static void EnsureTransitionAllowed(string currentStatus, string newStatus)
        {
            if (currentStatus == newStatus)
            {
                return;
            }

            var isAllowed = currentStatus switch
            {
                StatusPending => newStatus is StatusConfirmed or StatusCancelled or StatusExpired,
                StatusConfirmed => newStatus is StatusCompleted or StatusCancelled or StatusExpired,
                StatusCompleted => false,
                StatusCancelled => false,
                StatusExpired => false,
                _ => false
            };

            if (!isAllowed)
            {
                throw new UserException(
                    $"Invalid reservation transition from '{currentStatus}' to '{newStatus}'",
                    HttpStatusCode.BadRequest);
            }
        }

        private string? TryApplyCancellationRefund(ReservationDb reservation)
        {
            if (reservation.TotalPrice <= 0)
            {
                return null;
            }

            var user = Context.Users.Find(reservation.UserId);
            if (user == null)
            {
                throw new UserException("User not found", HttpStatusCode.NotFound);
            }

            var refundAlreadyExists = Context.Transactions.Any(t =>
                t.ReservationId == reservation.Id &&
                t.Status == TransactionStatus.Refunded);
            if (refundAlreadyExists)
            {
                return "Refund was already processed earlier";
            }

            var timeUntilStart = reservation.StartTime - DateTime.UtcNow;
            if (timeUntilStart < RefundCutoffWindow)
            {
                return "No coin refund: reservation was cancelled less than one hour before start time";
            }

            user.Coins += reservation.TotalPrice;
            Context.Transactions.Add(new Database.Transaction
            {
                UserId = reservation.UserId,
                ReservationId = reservation.Id,
                Amount = reservation.TotalPrice,
                Currency = "BAM",
                PaymentMethod = "Coins",
                Status = TransactionStatus.Refunded,
                CreatedAt = DateTime.UtcNow,
                PaymentDate = DateTime.UtcNow
            });

            return $"Refund issued: {reservation.TotalPrice:F2} coins returned";
        }

        private static void EnsureWithinOperatingHours(Database.ParkingLocation location, DateTime startUtc, DateTime endUtc)
        {
            if (location.Is24Hours)
            {
                return;
            }

            if (string.IsNullOrWhiteSpace(location.OperatingHours))
            {
                return;
            }

            if (!TryParseOperatingHours(location.OperatingHours!, out var open, out var close))
            {
                throw new UserException("Parking location operating hours are invalid", HttpStatusCode.BadRequest);
            }

            var localStart = startUtc.Kind == DateTimeKind.Utc
                ? TimeZoneInfo.ConvertTimeFromUtc(startUtc, TimeZoneInfo.Local)
                : startUtc.ToLocalTime();
            var localEnd = endUtc.Kind == DateTimeKind.Utc
                ? TimeZoneInfo.ConvertTimeFromUtc(endUtc, TimeZoneInfo.Local)
                : endUtc.ToLocalTime();

            var startTime = localStart.TimeOfDay;
            var endTime = localEnd.TimeOfDay;

            if (!IsWithinOperatingWindow(startTime, open, close) ||
                !IsWithinOperatingWindow(endTime, open, close))
            {
                throw new UserException(
                    $"Reservation must be within operating hours ({location.OperatingHours})",
                    HttpStatusCode.BadRequest);
            }
        }

        private static bool TryParseOperatingHours(string operatingHours, out TimeSpan open, out TimeSpan close)
        {
            open = default;
            close = default;

            var parts = operatingHours.Split('-', StringSplitOptions.TrimEntries);
            if (parts.Length != 2)
            {
                return false;
            }

            if (!TimeSpan.TryParseExact(parts[0], @"hh\:mm", CultureInfo.InvariantCulture, out open))
            {
                return false;
            }

            if (!TimeSpan.TryParseExact(parts[1], @"hh\:mm", CultureInfo.InvariantCulture, out close))
            {
                return false;
            }

            return true;
        }

        private static bool IsWithinOperatingWindow(TimeSpan value, TimeSpan open, TimeSpan close)
        {
            if (open == close)
            {
                return true;
            }

            if (open < close)
            {
                return value >= open && value <= close;
            }

            // Overnight range (e.g. 22:00-06:00).
            return value >= open || value <= close;
        }
    }
}

