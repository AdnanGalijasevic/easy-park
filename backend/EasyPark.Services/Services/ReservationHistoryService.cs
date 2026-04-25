using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Net;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;
using ReservationHistoryModel = EasyPark.Model.Models.ReservationHistory;
using ReservationHistoryDb = EasyPark.Services.Database.ReservationHistory;

namespace EasyPark.Services.Services
{
    public class ReservationHistoryService : BaseService<ReservationHistoryModel, ReservationHistorySearchObject, ReservationHistoryDb>, IReservationHistoryService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ReservationHistoryService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override IQueryable<ReservationHistoryDb> AddFilter(ReservationHistorySearchObject search, IQueryable<ReservationHistoryDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery
                .Include(rh => rh.Reservation)
                    .ThenInclude(r => r.ParkingSpot)
                .Include(rh => rh.User);

            if (search.ReservationId.HasValue)
            {
                filteredQuery = filteredQuery.Where(rh => rh.ReservationId == search.ReservationId.Value);
            }

            if (search.UserId.HasValue)
            {
                filteredQuery = filteredQuery.Where(rh => rh.UserId == search.UserId.Value);
            }

            if (search.ParkingLocationId.HasValue)
            {
                var parkingLocationId = search.ParkingLocationId.Value;
                filteredQuery = filteredQuery.Where(rh =>
                    rh.Reservation != null &&
                    rh.Reservation.ParkingSpot != null &&
                    rh.Reservation.ParkingSpot.ParkingLocationId == parkingLocationId);
            }

            if (!string.IsNullOrWhiteSpace(search.OldStatus))
            {
                filteredQuery = filteredQuery.Where(rh => rh.OldStatus == search.OldStatus);
            }

            if (!string.IsNullOrWhiteSpace(search.NewStatus))
            {
                filteredQuery = filteredQuery.Where(rh => rh.NewStatus == search.NewStatus);
            }

            if (search.ChangedFrom.HasValue)
            {
                filteredQuery = filteredQuery.Where(rh => rh.ChangedAt >= search.ChangedFrom.Value);
            }

            if (search.ChangedTo.HasValue)
            {
                filteredQuery = filteredQuery.Where(rh => rh.ChangedAt <= search.ChangedTo.Value);
            }

            filteredQuery = filteredQuery.OrderByDescending(rh => rh.ChangedAt);

            return filteredQuery;
        }

        public void LogStatusChange(int reservationId, string? oldStatus, string newStatus, string? changeReason = null, string? notes = null)
        {
            var reservation = Context.Reservations.Find(reservationId);
            if (reservation == null)
            {
                throw new UserException("Reservation not found", HttpStatusCode.NotFound);
            }

            var history = new ReservationHistoryDb
            {
                ReservationId = reservationId,
                UserId = CurrentUserHelper.TryGetUserId(_httpContextAccessor),
                OldStatus = oldStatus,
                NewStatus = newStatus,
                ChangeReason = changeReason,
                Notes = notes,
                ChangedAt = DateTime.UtcNow
            };

            Context.ReservationHistories.Add(history);
            Context.SaveChanges();
        }

        public override ReservationHistoryModel GetById(int id)
        {
            var entity = Context.Set<ReservationHistoryDb>()
                .Include(rh => rh.Reservation)
                .Include(rh => rh.User)
                .FirstOrDefault(rh => rh.Id == id);

            if (entity == null)
            {
                throw new UserException("Reservation history not found", HttpStatusCode.NotFound);
            }

            return Mapper.Map<ReservationHistoryModel>(entity);
        }

        public override PagedResult<ReservationHistoryModel> GetPaged(ReservationHistorySearchObject search)
        {
            var result = new List<ReservationHistoryModel>();

            var query = Context.Set<ReservationHistoryDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();

            result = Mapper.Map(list, result);

            var pagedResult = new PagedResult<ReservationHistoryModel>();
            pagedResult.ResultList = result;
            pagedResult.Count = count;

            return pagedResult;
        }

    }
}

