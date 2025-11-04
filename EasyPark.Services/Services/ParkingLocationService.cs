using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Net;
using System.Security.Claims;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using ParkingLocationModel = EasyPark.Model.Models.ParkingLocation;
using ParkingLocationDb = EasyPark.Services.Database.ParkingLocation;

namespace EasyPark.Services.Services
{
    public class ParkingLocationService : BaseCRUDService<ParkingLocationModel, ParkingLocationSearchObject, ParkingLocationDb, ParkingLocationInsertRequest, ParkingLocationUpdateRequest>, IParkingLocationService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ParkingLocationService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override IQueryable<ParkingLocationDb> AddFilter(ParkingLocationSearchObject search, IQueryable<ParkingLocationDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery.Include(pl => pl.CreatedByUser);

            if (!string.IsNullOrWhiteSpace(search?.FTS))
            {
                filteredQuery = filteredQuery.Where(x =>
                    x.Name.Contains(search.FTS) ||
                    x.Address.Contains(search.FTS) ||
                    x.City.Contains(search.FTS) ||
                    (x.Description != null && x.Description.Contains(search.FTS)));
            }

            if (!string.IsNullOrWhiteSpace(search?.City))
            {
                filteredQuery = filteredQuery.Where(x => x.City == search.City);
            }

            if (search.IsActive.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.IsActive == search.IsActive.Value);
            }

            if (search.HasVideoSurveillance.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasVideoSurveillance == search.HasVideoSurveillance.Value);
            }

            if (search.HasDisabledSpots.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasDisabledSpots == search.HasDisabledSpots.Value);
            }

            if (search.Is24Hours.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.Is24Hours == search.Is24Hours.Value);
            }

            if (search.HasOnlinePayment.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasOnlinePayment == search.HasOnlinePayment.Value);
            }

            if (search.HasElectricCharging.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasElectricCharging == search.HasElectricCharging.Value);
            }

            if (search.HasCoveredSpots.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasCoveredSpots == search.HasCoveredSpots.Value);
            }

            if (!string.IsNullOrWhiteSpace(search?.ParkingType))
            {
                filteredQuery = filteredQuery.Where(x => x.ParkingType == search.ParkingType);
            }

            if (search.MinPricePerHour.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.PricePerHour >= search.MinPricePerHour.Value);
            }

            if (search.MaxPricePerHour.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.PricePerHour <= search.MaxPricePerHour.Value);
            }

            // Distance-based filtering (if latitude/longitude provided)
            if (search.Latitude.HasValue && search.Longitude.HasValue && search.MaxDistance.HasValue)
            {
                // Simple distance calculation (Haversine formula would be better for production)
                // For now, using a simple bounding box approximation
                filteredQuery = filteredQuery.Where(x =>
                    Math.Abs((double)(x.Latitude - search.Latitude.Value)) <= (double)search.MaxDistance.Value / 111.0 &&
                    Math.Abs((double)(x.Longitude - search.Longitude.Value)) <= (double)search.MaxDistance.Value / 111.0);
            }

            filteredQuery = filteredQuery.OrderByDescending(p => p.CreatedAt);

            return filteredQuery;
        }

        public override void BeforeInsert(ParkingLocationInsertRequest request, ParkingLocationDb entity)
        {
            if (string.IsNullOrWhiteSpace(request.Name))
            {
                throw new UserException("Name is required", HttpStatusCode.BadRequest);
            }

            if (string.IsNullOrWhiteSpace(request.Address))
            {
                throw new UserException("Address is required", HttpStatusCode.BadRequest);
            }

            if (string.IsNullOrWhiteSpace(request.City))
            {
                throw new UserException("City is required", HttpStatusCode.BadRequest);
            }

            if (request.TotalSpots <= 0)
            {
                throw new UserException("Total spots must be greater than 0", HttpStatusCode.BadRequest);
            }

            if (request.PricePerHour < 0)
            {
                throw new UserException("Price per hour cannot be negative", HttpStatusCode.BadRequest);
            }

            // Set calculated fields (automatically set, not from request)
            entity.AverageRating = 0;
            entity.TotalReviews = 0;
            entity.PopularityScore = 0;

            // Set automatic fields
            entity.IsActive = true; // Default to active on creation
            entity.CreatedAt = DateTime.UtcNow;

            // Get current user ID from HttpContext
            var userIdClaim = _httpContextAccessor.HttpContext?.User?.FindFirst("UserId")?.Value 
                ?? _httpContextAccessor.HttpContext?.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            if (userIdClaim != null && int.TryParse(userIdClaim, out int userId))
            {
                var user = Context.Users.Find(userId);
                if (user != null)
                {
                    entity.CreatedBy = userId;
                }
                else
                {
                    throw new UserException("User not found", HttpStatusCode.NotFound);
                }
            }
            else
            {
                throw new UserException("User not authenticated", HttpStatusCode.Unauthorized);
            }
        }

        public override void BeforeUpdate(ParkingLocationUpdateRequest request, ParkingLocationDb entity)
        {
            if (entity == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            if (request.TotalSpots.HasValue && request.TotalSpots.Value <= 0)
            {
                throw new UserException("Total spots must be greater than 0", HttpStatusCode.BadRequest);
            }

            if (request.PricePerHour.HasValue && request.PricePerHour.Value < 0)
            {
                throw new UserException("Price per hour cannot be negative", HttpStatusCode.BadRequest);
            }

            // Set automatic field
            entity.UpdatedAt = DateTime.UtcNow;

            // Note: AverageRating, TotalReviews, PopularityScore are calculated automatically
            // and should NOT be updated through this method - they are updated when Reviews are added/updated
            // Note: CreatedBy and CreatedAt cannot be changed
        }

        public override ParkingLocationModel GetById(int id)
        {
            var entity = Context.Set<ParkingLocationDb>()
                .Include(pl => pl.CreatedByUser)
                .FirstOrDefault(x => x.Id == id);

            if (entity == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            return Mapper.Map<ParkingLocationModel>(entity);
        }

        public override PagedResult<ParkingLocationModel> GetPaged(ParkingLocationSearchObject search)
        {
            var result = new List<ParkingLocationModel>();

            var query = Context.Set<ParkingLocationDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();

            if (search?.Page.HasValue == true && search?.PageSize.HasValue == true)
            {
                query = query.Skip(search.Page.Value * search.PageSize.Value).Take(search.PageSize.Value);
            }

            var list = query.ToList();

            result = Mapper.Map(list, result);

            var pagedResult = new PagedResult<ParkingLocationModel>();
            pagedResult.ResultList = result;
            pagedResult.Count = count;

            return pagedResult;
        }

        /// <summary>
        /// Updates calculated fields (AverageRating, TotalReviews) based on Reviews.
        /// This method should be called from ReviewService when a Review is added, updated, or deleted.
        /// </summary>
        /// <param name="parkingLocationId">ID of the parking location to update</param>
        public void UpdateCalculatedFields(int parkingLocationId)
        {
            var parkingLocation = Context.Set<ParkingLocationDb>().Find(parkingLocationId);
            if (parkingLocation == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            // TODO: Uncomment when Review table is created
            // var reviews = Context.Set<Review>()
            //     .Where(r => r.ParkingLocationId == parkingLocationId)
            //     .ToList();

            // if (reviews.Any())
            // {
            //     parkingLocation.TotalReviews = reviews.Count;
            //     parkingLocation.AverageRating = (decimal)reviews.Average(r => r.Rating);
            // }
            // else
            // {
            //     parkingLocation.TotalReviews = 0;
            //     parkingLocation.AverageRating = 0;
            // }

            // Update PopularityScore based on multiple factors
            // This is a simple calculation - can be enhanced later
            // PopularityScore could be based on: reservations count, reviews count, average rating, etc.
            // For now, we'll set it to 0 or calculate it when Review/Reservation tables are created

            Context.SaveChanges();
        }
    }
}

