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
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;
using ParkingLocationModel = EasyPark.Model.Models.ParkingLocation;
using ParkingLocationDb = EasyPark.Services.Database.ParkingLocation;
using ReservationDb = EasyPark.Services.Database.Reservation;
using CityCoordinateModel = EasyPark.Model.Models.CityCoordinate;

namespace EasyPark.Services.Services
{
    public class ParkingLocationService : BaseCRUDService<ParkingLocationModel, ParkingLocationSearchObject, ParkingLocationDb, ParkingLocationInsertRequest, ParkingLocationUpdateRequest>, IParkingLocationService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ParkingLocationService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override ParkingLocationModel Insert(ParkingLocationInsertRequest request)
        {
            // Create entity from request
            ParkingLocationDb entity = Mapper.Map<ParkingLocationDb>(request);
            ApplyPhotoFromBase64(request.Photo, entity, allowClear: true);
            
            // Call BeforeInsert which will set calculated fields
            BeforeInsert(request, entity);
            
            Context.Add(entity);
            Context.SaveChanges();

            // Load ParkingSpots to calculate TotalSpots
            Context.Entry(entity).Collection(e => e.ParkingSpots).Load();

            // Return fully hydrated model (City/CreatedBy loaded) to avoid null mapping issues.
            return GetById(entity.Id);
        }

        public override ParkingLocationModel Update(int id, ParkingLocationUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);

            var entity = Context.Set<ParkingLocationDb>().Find(id);
            if (entity == null)
                throw new UserException("Record not found", HttpStatusCode.NotFound);

            BeforeUpdate(request, entity);

            Mapper.Map(request, entity);
            Context.SaveChanges();

            // Return fully hydrated model (City/CreatedBy loaded) to avoid null mapping issues.
            return GetById(id);
        }

        public override IQueryable<ParkingLocationDb> AddFilter(ParkingLocationSearchObject search, IQueryable<ParkingLocationDb> query)
        {
            ArgumentNullException.ThrowIfNull(search);
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery.Include(pl => pl.CreatedByUser);
            filteredQuery = filteredQuery.Include(pl => pl.City);

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                filteredQuery = filteredQuery.Where(x =>
                    x.Name.Contains(search.FTS) ||
                    x.Address.Contains(search.FTS) ||
                    x.City.Name.Contains(search.FTS) ||
                    (x.Description != null && x.Description.Contains(search.FTS)));
            }

            if (search.CityId.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.CityId == search.CityId.Value);
            }
            else if (!string.IsNullOrWhiteSpace(search.City))
            {
                filteredQuery = filteredQuery.Where(x => x.City.Name == search.City);
            }

            if (search.IsActive.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.IsActive == search.IsActive.Value);
            }

            if (search.HasVideoSurveillance.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasVideoSurveillance == search.HasVideoSurveillance.Value);
            }

            if (search.Is24Hours.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.Is24Hours == search.Is24Hours.Value);
            }

            if (search.HasDisabledSpots.HasValue)
            {
                var want = search.HasDisabledSpots.Value;
                filteredQuery = filteredQuery.Where(x =>
                    x.ParkingSpots.Any(s => s.SpotType == "Disabled" && s.IsActive) == want);
            }

            if (search.HasOnlinePayment.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasOnlinePayment == search.HasOnlinePayment.Value);
            }

            if (search.HasElectricCharging.HasValue)
            {
                var want = search.HasElectricCharging.Value;
                filteredQuery = filteredQuery.Where(x =>
                    x.ParkingSpots.Any(s => s.SpotType == "Electric" && s.IsActive) == want);
            }

            if (search.HasCoveredSpots.HasValue)
            {
                var want = search.HasCoveredSpots.Value;
                filteredQuery = filteredQuery.Where(x =>
                    x.ParkingSpots.Any(s => s.SpotType == "Covered" && s.IsActive) == want);
            }

            if (!string.IsNullOrWhiteSpace(search.ParkingType))
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

            if (search.Latitude.HasValue && search.Longitude.HasValue && search.MaxDistance.HasValue)
            {
                // Bounding-box pre-filter (1 degree ≈ 111 km). Haversine applied in recommendation scoring.
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

            if (request.CityId <= 0)
            {
                throw new UserException("Valid CityId is required", HttpStatusCode.BadRequest);
            }

            var cityExists = Context.Cities.Any(c => c.Id == request.CityId);
            if (!cityExists)
            {
                throw new UserException("Selected city does not exist", HttpStatusCode.BadRequest);
            }

            // TotalSpots is NOT stored in DB - it is calculated dynamically from ParkingSpots.Count in DTO
            // No validation needed - TotalSpots doesn't exist in DB model

            if (request.PricePerHour < 0)
            {
                throw new UserException("Price per hour cannot be negative", HttpStatusCode.BadRequest);
            }

            // Set calculated fields (automatically set, not from request)
            // TotalSpots is NOT stored in DB - it is calculated dynamically from ParkingSpots.Count
            entity.AverageRating = 0;
            entity.TotalReviews = 0;
            entity.PopularityScore = 0;

            entity.IsActive = true;
            entity.CreatedAt = DateTime.UtcNow;

            entity.CreatedBy = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
        }

        public override void BeforeUpdate(ParkingLocationUpdateRequest request, ParkingLocationDb entity)
        {
            if (entity == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            // TotalSpots is NOT stored in DB - it is calculated dynamically from ParkingSpots.Count in DTO
            // No validation needed - TotalSpots doesn't exist in DB model

            if (request.PricePerHour.HasValue && request.PricePerHour.Value < 0)
            {
                throw new UserException("Price per hour cannot be negative", HttpStatusCode.BadRequest);
            }

            if (request.CityId.HasValue)
            {
                var cityExists = Context.Cities.Any(c => c.Id == request.CityId.Value);
                if (!cityExists)
                {
                    throw new UserException("Selected city does not exist", HttpStatusCode.BadRequest);
                }
            }

            // Set automatic field
            entity.UpdatedAt = DateTime.UtcNow;

            if (request.Photo != null)
            {
                ApplyPhotoFromBase64(request.Photo, entity, allowClear: true);
                request.Photo = null;
            }
            
            // TotalSpots is NOT stored in DB - it is calculated dynamically from ParkingSpots.Count in DTO
        }

        private static void ApplyPhotoFromBase64(string? rawPhoto, ParkingLocationDb entity, bool allowClear)
        {
            if (rawPhoto == null)
            {
                return;
            }

            var normalized = rawPhoto.Trim();
            if (string.IsNullOrWhiteSpace(normalized))
            {
                if (allowClear)
                {
                    entity.Photo = null;
                }
                return;
            }

            var commaIndex = normalized.IndexOf(',');
            if (commaIndex >= 0 && normalized.Contains(";base64", StringComparison.OrdinalIgnoreCase))
            {
                normalized = normalized[(commaIndex + 1)..];
            }

            try
            {
                entity.Photo = Convert.FromBase64String(normalized);
            }
            catch (FormatException)
            {
                throw new UserException("Photo must be a valid base64 string", HttpStatusCode.BadRequest);
            }
        }

        public override ParkingLocationModel GetById(int id)
        {
            var entity = Context.Set<ParkingLocationDb>()
                .Include(pl => pl.CreatedByUser)
                .Include(pl => pl.City)
                .Include(pl => pl.ParkingSpots)
                .FirstOrDefault(x => x.Id == id);

            if (entity == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            var model = Mapper.Map<ParkingLocationModel>(entity);
            model.TotalSpots = entity.ParkingSpots.Count;
            return model;
        }

        public override PagedResult<ParkingLocationModel> GetPaged(ParkingLocationSearchObject search)
        {
            var result = new List<ParkingLocationModel>();

            var query = Context.Set<ParkingLocationDb>()
                .Include(pl => pl.ParkingSpots) // Include spots to count
                .AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();

            result = Mapper.Map(list, result);
            
            // Calculate TotalSpots dynamically
            for (int i = 0; i < list.Count; i++)
            {
                result[i].TotalSpots = list[i].ParkingSpots.Count;
            }

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

            var reviews = Context.Set<Database.Review>()
                .Where(r => r.ParkingLocationId == parkingLocationId)
                .ToList();

            if (reviews.Any())
            {
                parkingLocation.TotalReviews = reviews.Count;
                parkingLocation.AverageRating = (decimal)reviews.Average(r => r.Rating);
            }
            else
            {
                parkingLocation.TotalReviews = 0;
                parkingLocation.AverageRating = 0;
            }

            // Update PopularityScore based on multiple factors
            // This is a simple calculation - can be enhanced later
            // PopularityScore could be based on: reservations count, reviews count, average rating, etc.
            // For now, we'll set it to 0 or calculate it when Review/Reservation tables are created

            Context.SaveChanges();
        }

        /// <summary>
        /// Content-Based Filtering (CBF) recommendation algorithm.
        /// Builds a user preference profile from completed reservations, then scores all active locations
        /// by feature similarity (12 boolean amenities + price range). Haversine distance bonus applied
        /// when user GPS coordinates are provided. Returns scores in [0.0, 1.0] range.
        /// </summary>
        public List<EasyPark.Model.Models.ParkingLocation> GetRecommendationScores(int userId, int? cityId = null)
        {
            var scoredLocations = new List<(ParkingLocationDb Location, decimal Score, string Explanation)>();

            // Get user's previous completed reservations
            var userReservations = Context.Set<ReservationDb>()
                .Include(r => r.ParkingSpot)
                    .ThenInclude(ps => ps.ParkingLocation)
                        .ThenInclude(pl => pl.ParkingSpots)
                .Where(r => r.UserId == userId && r.Status == "Completed")
                .ToList();

            if (!userReservations.Any())
            {
                // Fallback: No history — return top-rated locations in the selected city.
                var fallbackQuery = Context.Set<ParkingLocationDb>()
                    .Include(pl => pl.ParkingSpots)
                    .Include(pl => pl.City)
                    .Include(pl => pl.CreatedByUser)
                    .Where(pl => pl.IsActive);

                if (cityId.HasValue)
                    fallbackQuery = fallbackQuery.Where(pl => pl.CityId == cityId.Value);

                var fallbackLocations = fallbackQuery.ToList();

                var fallbackTop3 = fallbackLocations
                    .OrderByDescending(l => l.AverageRating)
                    .Take(3)
                    .ToList();

                var fallbackResultList = new List<EasyPark.Model.Models.ParkingLocation>();
                foreach (var item in fallbackTop3)
                {
                    var dto = Mapper.Map<EasyPark.Model.Models.ParkingLocation>(item);
                    dto.CbfScore = item.AverageRating > 0 ? Math.Round((item.AverageRating / 5.0m) * 100, 0) : 50;
                    dto.CbfExplanation = "Highly rated in your selected city";
                    fallbackResultList.Add(dto);
                }
                return fallbackResultList;
            }

            // Analyze user preferences from previous reservations
            var userPreferredLocations = userReservations
                .Select(r => r.ParkingSpot.ParkingLocation)
                .GroupBy(l => l.Id)
                .Select(g => g.First())
                .ToList();

            // Calculate average preferences from user's previous locations
            var avgHasVideoSurveillance = userPreferredLocations.Average(l => l.HasVideoSurveillance ? 1.0m : 0.0m);
            var avgHasNightSurveillance = userPreferredLocations.Average(l => l.HasNightSurveillance ? 1.0m : 0.0m);
            var avgHasDisabledSpots = userPreferredLocations.Average(l => LocationHasActiveSpotType(l, "Disabled") ? 1.0m : 0.0m);
            var avgHasRamp = userPreferredLocations.Average(l => l.HasRamp ? 1.0m : 0.0m);
            var avgIs24Hours = userPreferredLocations.Average(l => l.Is24Hours ? 1.0m : 0.0m);
            var avgHasOnlinePayment = userPreferredLocations.Average(l => l.HasOnlinePayment ? 1.0m : 0.0m);
            var avgHasElectricCharging = userPreferredLocations.Average(l => LocationHasActiveSpotType(l, "Electric") ? 1.0m : 0.0m);
            var avgHasCoveredSpots = userPreferredLocations.Average(l => LocationHasActiveSpotType(l, "Covered") ? 1.0m : 0.0m);
            var avgHasSecurityGuard = userPreferredLocations.Average(l => l.HasSecurityGuard ? 1.0m : 0.0m);
            var avgHasWifi = userPreferredLocations.Average(l => l.HasWifi ? 1.0m : 0.0m);
            var avgHasRestroom = userPreferredLocations.Average(l => l.HasRestroom ? 1.0m : 0.0m);
            var avgHasAttendant = userPreferredLocations.Average(l => l.HasAttendant ? 1.0m : 0.0m);

            // Get average price preference
            var avgPricePerHour = userPreferredLocations.Average(l => (double)l.PricePerHour);

            // Get all active parking locations (filtered by city if provided)
            var locationQuery = Context.Set<ParkingLocationDb>()
                .Include(pl => pl.ParkingSpots)
                .Include(pl => pl.City)
                .Include(pl => pl.CreatedByUser)
                .Where(pl => pl.IsActive);

            if (cityId.HasValue)
                locationQuery = locationQuery.Where(pl => pl.CityId == cityId.Value);

            var allLocations = locationQuery.ToList();

            // Score each location: 12 boolean features × 0.08 (max 0.96) + price (0.20) + distance bonus (0.16)
            foreach (var location in allLocations)
            {
                decimal matchScore = 0.0m;

                var matchedFeatures = new List<string>();
                if (Math.Abs((location.HasVideoSurveillance ? 1.0m : 0.0m) - avgHasVideoSurveillance) < 0.5m) { matchScore += 0.08m; if(location.HasVideoSurveillance) matchedFeatures.Add("Video Surveillance"); }
                if (Math.Abs((location.HasNightSurveillance ? 1.0m : 0.0m) - avgHasNightSurveillance) < 0.5m) { matchScore += 0.08m; if(location.HasNightSurveillance) matchedFeatures.Add("Night Surveillance"); }
                if (Math.Abs((LocationHasActiveSpotType(location, "Disabled") ? 1.0m : 0.0m) - avgHasDisabledSpots) < 0.5m) { matchScore += 0.08m; if(LocationHasActiveSpotType(location, "Disabled")) matchedFeatures.Add("Disabled Spots"); }
                if (Math.Abs((location.HasRamp ? 1.0m : 0.0m) - avgHasRamp) < 0.5m) { matchScore += 0.08m; if(location.HasRamp) matchedFeatures.Add("Ramp"); }
                if (Math.Abs((location.Is24Hours ? 1.0m : 0.0m) - avgIs24Hours) < 0.5m) { matchScore += 0.08m; if(location.Is24Hours) matchedFeatures.Add("24h"); }
                if (Math.Abs((location.HasOnlinePayment ? 1.0m : 0.0m) - avgHasOnlinePayment) < 0.5m) { matchScore += 0.08m; if(location.HasOnlinePayment) matchedFeatures.Add("Online Payment"); }
                if (Math.Abs((LocationHasActiveSpotType(location, "Electric") ? 1.0m : 0.0m) - avgHasElectricCharging) < 0.5m) { matchScore += 0.08m; if(LocationHasActiveSpotType(location, "Electric")) matchedFeatures.Add("EV Charging"); }
                if (Math.Abs((LocationHasActiveSpotType(location, "Covered") ? 1.0m : 0.0m) - avgHasCoveredSpots) < 0.5m) { matchScore += 0.08m; if(LocationHasActiveSpotType(location, "Covered")) matchedFeatures.Add("Covered Spots"); }
                if (Math.Abs((location.HasSecurityGuard ? 1.0m : 0.0m) - avgHasSecurityGuard) < 0.5m) { matchScore += 0.08m; if(location.HasSecurityGuard) matchedFeatures.Add("Security Guard"); }
                if (Math.Abs((location.HasWifi ? 1.0m : 0.0m) - avgHasWifi) < 0.5m) { matchScore += 0.08m; if(location.HasWifi) matchedFeatures.Add("WiFi"); }
                if (Math.Abs((location.HasRestroom ? 1.0m : 0.0m) - avgHasRestroom) < 0.5m) { matchScore += 0.08m; if(location.HasRestroom) matchedFeatures.Add("Restrooms"); }
                if (Math.Abs((location.HasAttendant ? 1.0m : 0.0m) - avgHasAttendant) < 0.5m) { matchScore += 0.08m; if(location.HasAttendant) matchedFeatures.Add("Attendant"); }

                // Price similarity (normalized, max 0.2 points)
                var priceDiff = Math.Abs((double)location.PricePerHour - avgPricePerHour);
                var maxPrice = userPreferredLocations.Max(l => (double)l.PricePerHour);
                var minPrice = userPreferredLocations.Min(l => (double)l.PricePerHour);
                var priceRange = maxPrice - minPrice;
                bool goodPrice = false;
                if (priceRange > 0)
                {
                    var priceSimilarity = 1.0m - (decimal)(Math.Min(priceDiff / priceRange, 1.0));
                    matchScore += priceSimilarity * 0.2m;
                    if (priceSimilarity > 0.7m) goodPrice = true;
                }
                else
                {
                    matchScore += 0.2m; // If all prices are same, give full points
                    goodPrice = true;
                }

                // Normalize score to 0.0-1.0 range
                var normalizedScore = Math.Min(1.0m, Math.Max(0.0m, matchScore));

                // Distance factor removed — city filter handles proximity now.

                string explanation = "Good match based on your history.";
                var reasons = new List<string>();
                if (goodPrice) reasons.Add("Price fits your preference");
                if (matchedFeatures.Any())
                {
                    reasons.Add("Has " + string.Join(", ", matchedFeatures.Take(2)));
                }

                if (reasons.Any())
                {
                    explanation = string.Join(". ", reasons) + ".";
                }

                scoredLocations.Add((location, normalizedScore, explanation));
            }

            var top3 = scoredLocations.OrderByDescending(x => x.Score).Take(3).ToList();
            var resultList = new List<EasyPark.Model.Models.ParkingLocation>();

            foreach (var item in top3)
            {
                var dto = Mapper.Map<EasyPark.Model.Models.ParkingLocation>(item.Location);
                dto.CbfScore = Math.Round(item.Score * 100, 0); // Convert to percentage
                dto.CbfExplanation = item.Explanation;
                resultList.Add(dto);
            }

            return resultList;
        }

        private static double HaversineDistance(double lat1, double lon1, double lat2, double lon2)
        {
            const double R = 6371; // Earth radius in km
            var dLat = (lat2 - lat1) * Math.PI / 180.0;
            var dLon = (lon2 - lon1) * Math.PI / 180.0;
            var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                    Math.Cos(lat1 * Math.PI / 180.0) * Math.Cos(lat2 * Math.PI / 180.0) *
                    Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return R * c;
        }

        public List<SpotTypeAvailability> GetAvailability(int locationId, DateTime from, DateTime to)
        {
            var location = Context.ParkingLocations
                .Include(pl => pl.ParkingSpots)
                .FirstOrDefault(pl => pl.Id == locationId);
            if (location == null)
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);

            var spotTypes = new[] { "Regular", "Disabled", "Electric", "Covered" };
            var results = new List<SpotTypeAvailability>();

            foreach (var spotType in spotTypes)
            {
                var spots = location.ParkingSpots
                    .Where(s => s.SpotType == spotType && s.IsActive)
                    .ToList();
                var total = spots.Count;
                var spotIds = spots.Select(s => s.Id).ToList();

                var row = new SpotTypeAvailability
                {
                    SpotType = spotType,
                    TotalSpots = total,
                    BusySlots = new List<TimeSlot>(),
                    FreeSlots = new List<TimeSlot>(),
                };

                if (total == 0)
                {
                    results.Add(row);
                    continue;
                }

                var reservations = Context.Reservations
                    .AsNoTracking()
                    .Where(r =>
                        spotIds.Contains(r.ParkingSpotId) &&
                        r.Status != "Cancelled" &&
                        r.Status != "Expired" &&
                        r.StartTime < to &&
                        r.EndTime > from)
                    .Select(r => new { r.StartTime, r.EndTime })
                    .ToList();

                var intervals = reservations
                    .Select(r =>
                    {
                        var s = r.StartTime < from ? from : r.StartTime;
                        var e = r.EndTime > to ? to : r.EndTime;
                        return (Start: s, End: e);
                    })
                    .Where(x => x.Start < x.End)
                    .ToList();

                var boundaries = new SortedSet<DateTime> { from, to };
                foreach (var iv in intervals)
                {
                    boundaries.Add(iv.Start);
                    boundaries.Add(iv.End);
                }

                var points = boundaries.ToList();
                for (var i = 0; i < points.Count - 1; i++)
                {
                    var segStart = points[i];
                    var segEnd = points[i + 1];
                    if (segStart >= segEnd) continue;

                    var overlapping = intervals.Count(iv => iv.Start < segEnd && iv.End > segStart);
                    var available = Math.Max(0, total - overlapping);

                    var slot = new TimeSlot
                    {
                        Start = segStart,
                        End = segEnd,
                        AvailableSpots = available,
                    };

                    if (available == 0)
                        row.BusySlots.Add(slot);
                    else
                        row.FreeSlots.Add(slot);
                }

                results.Add(row);
            }

            return results;
        }

        public List<CityCoordinateModel> GetCityCoordinates()
        {
            return Context.CityCoordinates
                .AsNoTracking()
                .OrderBy(c => c.City)
                .Select(c => new CityCoordinateModel
                {
                    City = c.City,
                    Latitude = c.Latitude,
                    Longitude = c.Longitude
                })
                .ToList();
        }

        public List<ParkingLocationName> GetParkingLocationNames()
        {
            return Context.ParkingLocations
                .AsNoTracking()
                .OrderBy(p => p.Name)
                .Select(p => new ParkingLocationName
                {
                    Id = p.Id,
                    Name = p.Name
                })
                .ToList();
        }

        private static bool LocationHasActiveSpotType(ParkingLocationDb location, string spotType)
        {
            return location.ParkingSpots.Any(s => s.SpotType == spotType && s.IsActive);
        }
    }
}

