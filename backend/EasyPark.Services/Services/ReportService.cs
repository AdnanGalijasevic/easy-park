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
using EasyPark.Services.Pdf;
using ReportModel = EasyPark.Model.Models.Report;
using ReportDb = EasyPark.Services.Database.Report;

namespace EasyPark.Services.Services
{
    public class ReportService : BaseCRUDService<ReportModel, ReportSearchObject, ReportDb, ReportInsertRequest, ReportUpdateRequest>, IReportService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ReportService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override IQueryable<ReportDb> AddFilter(ReportSearchObject search, IQueryable<ReportDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery
                .Include(r => r.ParkingLocation)
                .Include(r => r.User);

            if (search.ParkingLocationId.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.ParkingLocationId == search.ParkingLocationId.Value);
            }

            if (search.UserId.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.UserId == search.UserId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.ReportType))
            {
                filteredQuery = filteredQuery.Where(r => r.ReportType == search.ReportType);
            }

            if (search.PeriodStartFrom.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.PeriodStart >= search.PeriodStartFrom.Value);
            }

            if (search.PeriodStartTo.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.PeriodStart <= search.PeriodStartTo.Value);
            }

            filteredQuery = filteredQuery.OrderByDescending(r => r.CreatedAt);

            return filteredQuery;
        }

        public override void BeforeInsert(ReportInsertRequest request, ReportDb entity)
        {
            var validReportTypes = new[] { "Daily", "Weekly", "Monthly", "Yearly" };
            if (!validReportTypes.Contains(request.ReportType))
            {
                throw new UserException($"Invalid report type. Valid types are: {string.Join(", ", validReportTypes)}", HttpStatusCode.BadRequest);
            }

            if (request.PeriodEnd <= request.PeriodStart)
            {
                throw new UserException("PeriodEnd must be after PeriodStart", HttpStatusCode.BadRequest);
            }

            if (request.ParkingLocationId.HasValue)
            {
                var parkingLocation = Context.ParkingLocations.Find(request.ParkingLocationId.Value);
                if (parkingLocation == null)
                {
                    throw new UserException("Parking location not found", HttpStatusCode.NotFound);
                }
            }

            var reservations = Context.Reservations
                .Where(r => r.Status == "Completed" &&
                           r.StartTime >= request.PeriodStart &&
                           r.EndTime <= request.PeriodEnd);

            if (request.ParkingLocationId.HasValue)
            {
                reservations = reservations.Where(r => r.ParkingSpot.ParkingLocationId == request.ParkingLocationId.Value);
            }

            var completedReservations = reservations.ToList();
            var transactions = Context.Transactions
                .Where(t => t.Status == "Completed" &&
                           t.CreatedAt >= request.PeriodStart &&
                           t.CreatedAt <= request.PeriodEnd);

            if (request.ParkingLocationId.HasValue)
            {
                transactions = transactions.Where(t => t.Reservation != null &&
                                                     t.Reservation.ParkingSpot.ParkingLocationId == request.ParkingLocationId.Value);
            }

            var completedTransactions = transactions.ToList();

            entity.TotalRevenue = completedTransactions.Sum(t => t.Amount);
            entity.TotalReservations = completedReservations.Count;

            if (request.ParkingLocationId.HasValue)
            {
                var reviews = Context.Reviews
                    .Where(r => r.ParkingLocationId == request.ParkingLocationId.Value &&
                               r.CreatedAt >= request.PeriodStart &&
                               r.CreatedAt <= request.PeriodEnd)
                    .ToList();

                if (reviews.Any())
                {
                    entity.AverageRating = (decimal)reviews.Average(r => r.Rating);
                }
            }

            entity.UserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            entity.CreatedAt = DateTime.UtcNow;
        }

        public override void BeforeUpdate(ReportUpdateRequest request, ReportDb entity)
        {
            throw new UserException("Reports cannot be updated", HttpStatusCode.BadRequest);
        }

        public override ReportModel GetById(int id)
        {
            var entity = Context.Set<ReportDb>()
                .Include(r => r.ParkingLocation)
                .Include(r => r.User)
                .FirstOrDefault(r => r.Id == id);

            if (entity == null)
            {
                throw new UserException("Report not found", HttpStatusCode.NotFound);
            }

            return Mapper.Map<ReportModel>(entity);
        }

        public override PagedResult<ReportModel> GetPaged(ReportSearchObject search)
        {
            var result = new List<ReportModel>();

            var query = Context.Set<ReportDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();

            result = Mapper.Map(list, result);

            var pagedResult = new PagedResult<ReportModel>();
            pagedResult.ResultList = result;
            pagedResult.Count = count;

            return pagedResult;
        }

        public byte[] GenerateMonthlyAdminReportPdf(int year, int month, bool graphsOnly = false)
        {
            if (month is < 1 or > 12)
                throw new UserException("Month must be between 1 and 12.", HttpStatusCode.BadRequest);

            var start = new DateTime(year, month, 1, 0, 0, 0, DateTimeKind.Utc);
            var end = start.AddMonths(1);
            var daysInMonth = DateTime.DaysInMonth(year, month);

            var monthRevenue = Context.Transactions.AsNoTracking()
                .Where(t => t.Status == "Completed" && t.CreatedAt >= start && t.CreatedAt < end)
                .Sum(t => (decimal?)t.Amount) ?? 0m;

            var monthReservations = Context.Reservations.AsNoTracking()
                .Count(r => r.Status == "Completed" && r.StartTime >= start && r.StartTime < end);

            var points = new List<DailyPoint>();
            for (var d = 1; d <= daysInMonth; d++)
            {
                var dayStart = new DateTime(year, month, d, 0, 0, 0, DateTimeKind.Utc);
                var dayEnd = dayStart.AddDays(1);
                var rev = Context.Transactions.AsNoTracking()
                    .Where(t => t.Status == "Completed" && t.CreatedAt >= dayStart && t.CreatedAt < dayEnd)
                    .Sum(t => (decimal?)t.Amount) ?? 0m;
                var res = Context.Reservations.AsNoTracking()
                    .Count(r => r.Status == "Completed" && r.StartTime >= dayStart && r.StartTime < dayEnd);
                points.Add(new DailyPoint { Day = d, Revenue = rev, Reservations = res });
            }

            return AdminMonthlyReportPdfDocument.Generate(year, month, points, monthRevenue, monthReservations,
                DateTime.UtcNow, graphsOnly);
        }
    }
}

