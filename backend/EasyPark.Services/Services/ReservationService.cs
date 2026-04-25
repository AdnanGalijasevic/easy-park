using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Net;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
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
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IReservationHistoryService _historyService;
        private readonly IRabbitMQService _rabbitMQService;

        public ReservationService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor, IReservationHistoryService historyService, IRabbitMQService rabbitMQService) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
            _historyService = historyService;
            _rabbitMQService = rabbitMQService;
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
                filteredQuery = filteredQuery.Where(r => r.Status == search.Status);
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
            // ── Validate times first ────────────────────────────────────────
            if (request.EndTime <= request.StartTime)
                throw new UserException("End time must be after start time", HttpStatusCode.BadRequest);

            if (request.StartTime < DateTime.UtcNow)
                throw new UserException("Start time cannot be in the past", HttpStatusCode.BadRequest);

            // Resolve the parking spot
            Database.ParkingSpot? parkingSpot = null;

            if (request.ParkingSpotId.HasValue)
            {
                // Case A: Specific spot selected
                parkingSpot = Context.ParkingSpots
                    .Include(ps => ps.ParkingLocation)
                    .FirstOrDefault(ps => ps.Id == request.ParkingSpotId.Value)
                    ?? throw new UserException("Parking spot not found", HttpStatusCode.NotFound);

                if (!parkingSpot.IsActive)
                    throw new UserException("Parking spot is not active", HttpStatusCode.BadRequest);

                bool isTaken = Context.Reservations.Any(r =>
                    r.ParkingSpotId == parkingSpot.Id &&
                    r.Status != "Cancelled" && r.Status != "Expired" &&
                    r.StartTime < request.EndTime && r.EndTime > request.StartTime);

                if (isTaken)
                    throw new UserException($"Parking spot {parkingSpot.SpotNumber} is already reserved for this time period.", HttpStatusCode.BadRequest);
            }
            else
            {
                // Case B: Auto-assign first available spot of requested type
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

                // Use a loop to find the first spot without a conflicting reservation
                foreach (var spot in candidates)
                {
                    bool hasConflict = Context.Reservations.Any(r =>
                        r.ParkingSpotId == spot.Id &&
                        r.Status != "Cancelled" &&
                        r.Status != "Expired" &&
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

            // ── Assign parameters to entity ─────────────────────────────────
            entity.ParkingSpotId = parkingSpot.Id;

            // ── Price calculation using type-specific price ─────────────────
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

            // ── User balance check ──────────────────────────────────────────
            entity.UserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            var user = Context.Users.Find(entity.UserId)
                ?? throw new UserException("User not found", HttpStatusCode.NotFound);

            if (user.Coins < totalPrice)
                throw new UserException(
                    $"Insufficient balance. Required: {totalPrice:F2} Coins. Have: {user.Coins:F2} Coins.",
                    HttpStatusCode.BadRequest);

            user.Coins -= totalPrice;

            entity.Status = "Pending";
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

            if (!string.IsNullOrWhiteSpace(request.Status) && request.Status == "Cancelled")
            {
                if (!entity.CancellationAllowed)
                {
                    throw new UserException("Cancellation is not allowed for this reservation", HttpStatusCode.BadRequest);
                }
            }

            if (!string.IsNullOrWhiteSpace(request.Status))
            {
                var validStatuses = new[] { "Pending", "Active", "Completed", "Cancelled", "Expired" };
                if (!validStatuses.Contains(request.Status))
                {
                    throw new UserException($"Invalid status. Valid statuses are: {string.Join(", ", validStatuses)}", HttpStatusCode.BadRequest);
                }
            }

            // Ako se menja vrijeme, proveri preklapanje
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
                               r.Status != "Cancelled" &&
                               r.Status != "Expired" &&
                               r.EndTime > DateTime.UtcNow &&
                               r.StartTime < endTime && r.EndTime > startTime);

                if (overlappingReservation)
                {
                    throw new UserException("Parking spot is already reserved for this time period", HttpStatusCode.BadRequest);
                }
            }

            entity.UpdatedAt = DateTime.UtcNow;

            if (!string.IsNullOrWhiteSpace(request.Status) && request.Status != entity.Status)
            {
                var oldStatus = entity.Status;
                entity.Status = request.Status;
                _historyService.LogStatusChange(entity.Id, oldStatus, request.Status, request.CancellationReason);

                var reservation = GetById(entity.Id);
                var user = Context.Users.Find(reservation.UserId);
                var parkingSpot = Context.ParkingSpots
                    .Include(ps => ps.ParkingLocation)
                    .FirstOrDefault(ps => ps.Id == reservation.ParkingSpotId);

                if (user != null && parkingSpot != null)
                {
                    if (request.Status == "Cancelled")
                    {
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
                            CancellationReason = request.CancellationReason
                        };
                        _rabbitMQService.PublishMessage("easypark_reservation_cancelled", cancelledMessage);
                    }
                    else if (request.Status == "Completed")
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

            if (entity.Status == "Completed" || entity.Status == "Cancelled" || entity.Status == "Expired")
                throw new UserException($"Cannot confirm a reservation with status '{entity.Status}'", HttpStatusCode.BadRequest);

            var oldStatus = entity.Status;
            entity.Status = "Active";
            entity.UpdatedAt = DateTime.UtcNow;
            Context.SaveChanges();

            _historyService.LogStatusChange(entity.Id, oldStatus, "Active", "Confirmed via QR scan");

            return GetById(entity.Id);
        }
    }
}

