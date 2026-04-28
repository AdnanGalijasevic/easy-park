using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Net;
using EasyPark.Model;
using EasyPark.Model.Constants;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using ParkingSpotModel = EasyPark.Model.Models.ParkingSpot;
using ParkingSpotDb = EasyPark.Services.Database.ParkingSpot;

namespace EasyPark.Services.Services
{
    public class ParkingSpotService : BaseCRUDService<ParkingSpotModel, ParkingSpotSearchObject, ParkingSpotDb, ParkingSpotInsertRequest, ParkingSpotUpdateRequest>, IParkingSpotService
    {
        public ParkingSpotService(EasyParkDbContext context, IMapper mapper) : base(context, mapper)
        {
        }

        public override IQueryable<ParkingSpotDb> AddFilter(ParkingSpotSearchObject search, IQueryable<ParkingSpotDb> query)
        {
            ArgumentNullException.ThrowIfNull(search);
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery.Include(ps => ps.ParkingLocation).Include(ps => ps.Reservations);

            if (search.ParkingLocationId.HasValue)
            {
                filteredQuery = filteredQuery.Where(ps => ps.ParkingLocationId == search.ParkingLocationId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.SpotType))
            {
                filteredQuery = filteredQuery.Where(ps => ps.SpotType == search.SpotType);
            }

            if (search.IsActive.HasValue)
            {
                filteredQuery = filteredQuery.Where(ps => ps.IsActive == search.IsActive.Value);
            }

            if (search.CityId.HasValue)
            {
                filteredQuery = filteredQuery.Where(ps =>
                    ps.ParkingLocation != null && ps.ParkingLocation.CityId == search.CityId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                filteredQuery = filteredQuery.Where(ps =>
                    ps.ParkingLocation != null &&
                    (ps.SpotNumber.Contains(search.FTS) ||
                    ps.ParkingLocation.Name.Contains(search.FTS) ||
                    ps.ParkingLocation.Address.Contains(search.FTS)));
            }

            filteredQuery = filteredQuery.OrderBy(ps => ps.ParkingLocationId).ThenBy(ps => ps.SpotNumber);

            return filteredQuery;
        }

        public override void BeforeInsert(ParkingSpotInsertRequest request, ParkingSpotDb entity)
        {
            if (string.IsNullOrWhiteSpace(request.SpotNumber))
            {
                throw new UserException("Spot number is required", HttpStatusCode.BadRequest);
            }

            if (string.IsNullOrWhiteSpace(request.SpotType))
            {
                throw new UserException("Spot type is required", HttpStatusCode.BadRequest);
            }

            var validSpotTypes = new[] { "Regular", "Disabled", "Electric", "Covered" };
            if (!validSpotTypes.Contains(request.SpotType))
            {
                throw new UserException($"Invalid spot type. Valid types are: {string.Join(", ", validSpotTypes)}", HttpStatusCode.BadRequest);
            }

            var parkingLocation = Context.ParkingLocations.Find(request.ParkingLocationId);
            if (parkingLocation == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            var existingSpot = Context.ParkingSpots
                .FirstOrDefault(ps => ps.ParkingLocationId == request.ParkingLocationId && 
                                      ps.SpotNumber == request.SpotNumber);
            
            if (existingSpot != null)
            {
                throw new UserException($"Spot number '{request.SpotNumber}' already exists in this parking location", HttpStatusCode.BadRequest);
            }

            entity.CreatedAt = DateTime.UtcNow;
            entity.IsActive = request.IsActive;
        }

        public override ParkingSpotModel Insert(ParkingSpotInsertRequest request)
        {
            var result = base.Insert(request);
            return GetById(result.Id);
        }

        public override void BeforeUpdate(ParkingSpotUpdateRequest request, ParkingSpotDb entity)
        {
            if (entity == null)
            {
                throw new UserException("Parking spot not found", HttpStatusCode.NotFound);
            }

            if (request.ParkingLocationId.HasValue && request.ParkingLocationId.Value != entity.ParkingLocationId)
            {
                var parkingLocation = Context.ParkingLocations.Find(request.ParkingLocationId.Value);
                if (parkingLocation == null)
                {
                    throw new UserException("Parking location not found", HttpStatusCode.NotFound);
                }
            }

            if (!string.IsNullOrWhiteSpace(request.SpotNumber) && request.SpotNumber != entity.SpotNumber)
            {
                var locationId = request.ParkingLocationId ?? entity.ParkingLocationId;
                var existingSpot = Context.ParkingSpots
                    .FirstOrDefault(ps => ps.ParkingLocationId == locationId && 
                                          ps.SpotNumber == request.SpotNumber &&
                                          ps.Id != entity.Id);
                
                if (existingSpot != null)
                {
                    throw new UserException($"Spot number '{request.SpotNumber}' already exists in this parking location", HttpStatusCode.BadRequest);
                }
            }

            if (!string.IsNullOrWhiteSpace(request.SpotType))
            {
                var validSpotTypes = new[] { "Regular", "Disabled", "Electric", "Covered" };
                if (!validSpotTypes.Contains(request.SpotType))
                {
                    throw new UserException($"Invalid spot type. Valid types are: {string.Join(", ", validSpotTypes)}", HttpStatusCode.BadRequest);
                }
            }
        }

        public override ParkingSpotModel Update(int id, ParkingSpotUpdateRequest request)
        {
            base.Update(id, request);
            return GetById(id);
        }

        public override ParkingSpotModel GetById(int id)
        {
            var entity = Context.Set<ParkingSpotDb>()
                .Include(ps => ps.ParkingLocation)
                .FirstOrDefault(ps => ps.Id == id);

            if (entity == null)
            {
                throw new UserException("Parking spot not found", HttpStatusCode.NotFound);
            }

            return Mapper.Map<ParkingSpotModel>(entity);
        }

        public override PagedResult<ParkingSpotModel> GetPaged(ParkingSpotSearchObject search)
        {
            var result = new List<ParkingSpotModel>();

            var query = Context.Set<ParkingSpotDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();

            result = Mapper.Map(list, result);

            foreach (var item in result)
            {
                var dbSpot = list.First(s => s.Id == item.Id);
                var nextRes = dbSpot.Reservations
                    .Where(r => r.StartTime >= DateTime.UtcNow && r.Status != ReservationStatus.Cancelled)
                    .OrderBy(r => r.StartTime)
                    .FirstOrDefault();
                if (nextRes != null)
                {
                    item.NextReservationStart = nextRes.StartTime;
                    item.NextReservationEnd = nextRes.EndTime;
                }
            }

            var pagedResult = new PagedResult<ParkingSpotModel>();
            pagedResult.ResultList = result;
            pagedResult.Count = count;

            return pagedResult;
        }
    }
}

