using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Security.Claims;
using EasyPark.Model;
using EasyPark.Model.Constants;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;
using ParkingLocationModel = EasyPark.Model.Models.ParkingLocation;
using ParkingLocationDb = EasyPark.Services.Database.ParkingLocation;
using ReservationDb = EasyPark.Services.Database.Reservation;
using BookmarkDb = EasyPark.Services.Database.Bookmark;
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
            ParkingLocationDb entity = Mapper.Map<ParkingLocationDb>(request);
            ApplyPhotoFromBase64(request.Photo, entity, allowClear: true);

            BeforeInsert(request, entity);

            Context.Add(entity);
            Context.SaveChanges();

            Context.Entry(entity).Collection(e => e.ParkingSpots).Load();
            return GetById(entity.Id);
        }

        public override ParkingLocationModel Update(int id, ParkingLocationUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);

            var entity = Context.Set<ParkingLocationDb>().Find(id);
            if (entity == null)
                throw new NotFoundException("Parking location not found");

            BeforeUpdate(request, entity);

            Mapper.Map(request, entity);
            Context.SaveChanges();

            return GetById(id);
        }

        public override void Delete(int id)
        {
            var entity = Context.Set<ParkingLocationDb>().Find(id);
            if (entity == null)
            {
                throw new NotFoundException("Parking location not found");
            }

            var relatedSpotIds = Context.ParkingSpots
                .Where(s => s.ParkingLocationId == id)
                .Select(s => s.Id)
                .ToList();

            var relatedReservations = relatedSpotIds.Count == 0
                ? new List<ReservationDb>()
                : Context.Reservations
                    .Where(r => relatedSpotIds.Contains(r.ParkingSpotId))
                    .ToList();

            foreach (var reservation in relatedReservations)
            {
                var isRefundable =
                    reservation.Status != ReservationStatus.Cancelled &&
                    reservation.Status != ReservationStatus.Expired &&
                    reservation.TotalPrice > 0;

                if (isRefundable)
                {
                    var alreadyRefunded = Context.Transactions.Any(t =>
                        t.ReservationId == reservation.Id &&
                        t.Status == TransactionStatus.Refunded);

                    if (!alreadyRefunded)
                    {
                        var user = Context.Users.Find(reservation.UserId);
                        if (user != null)
                        {
                            user.Coins += reservation.TotalPrice;
                        }

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
                    }
                }
            }

            var relatedReviews = Context.Reviews.Where(r => r.ParkingLocationId == id).ToList();
            if (relatedReviews.Count > 0)
            {
                Context.Reviews.RemoveRange(relatedReviews);
            }

            var relatedBookmarks = Context.Bookmarks.Where(b => b.ParkingLocationId == id).ToList();
            if (relatedBookmarks.Count > 0)
            {
                Context.Bookmarks.RemoveRange(relatedBookmarks);
            }

            var relatedReservationIds = relatedReservations.Select(r => r.Id).ToList();
            if (relatedReservationIds.Count > 0)
            {
                var relatedHistories = Context.ReservationHistories
                    .Where(h => relatedReservationIds.Contains(h.ReservationId))
                    .ToList();
                if (relatedHistories.Count > 0)
                {
                    Context.ReservationHistories.RemoveRange(relatedHistories);
                }

                Context.Reservations.RemoveRange(relatedReservations);
            }

            if (relatedSpotIds.Count > 0)
            {
                var relatedSpots = Context.ParkingSpots
                    .Where(s => relatedSpotIds.Contains(s.Id))
                    .ToList();
                Context.ParkingSpots.RemoveRange(relatedSpots);
            }

            Context.Set<ParkingLocationDb>().Remove(entity);
            Context.SaveChanges();
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

            if (search.HasNightSurveillance.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasNightSurveillance == search.HasNightSurveillance.Value);
            }

            if (search.HasRamp.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasRamp == search.HasRamp.Value);
            }

            if (search.HasSecurityGuard.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasSecurityGuard == search.HasSecurityGuard.Value);
            }

            if (search.HasWifi.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasWifi == search.HasWifi.Value);
            }

            if (search.HasRestroom.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.HasRestroom == search.HasRestroom.Value);
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

            if (request.PricePerHour < 0)
            {
                throw new UserException("Price per hour cannot be negative", HttpStatusCode.BadRequest);
            }

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
                throw new NotFoundException("Parking location not found");
            }

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

            entity.UpdatedAt = DateTime.UtcNow;

            if (request.Photo != null)
            {
                ApplyPhotoFromBase64(request.Photo, entity, allowClear: true);
                request.Photo = null;
            }

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

            string? declaredMime = null;
            var commaIndex = normalized.IndexOf(',');
            if (commaIndex >= 0 && normalized.Contains(";base64", StringComparison.OrdinalIgnoreCase))
            {
                var metadata = normalized[..commaIndex];
                normalized = normalized[(commaIndex + 1)..];
                if (metadata.StartsWith("data:", StringComparison.OrdinalIgnoreCase))
                {
                    var mimePart = metadata[5..];
                    var semicolonIndex = mimePart.IndexOf(';');
                    declaredMime = semicolonIndex >= 0 ? mimePart[..semicolonIndex] : mimePart;
                }
            }

            try
            {
                var bytes = Convert.FromBase64String(normalized);
                ValidatePhotoMimeType(declaredMime, bytes);
                entity.Photo = bytes;
            }
            catch (FormatException)
            {
                throw new UserException("Photo must be a valid base64 string", HttpStatusCode.BadRequest);
            }
        }

        private static void ValidatePhotoMimeType(string? declaredMime, byte[] bytes)
        {
            if (bytes.Length == 0)
            {
                throw new UserException("Photo content cannot be empty", HttpStatusCode.BadRequest);
            }

            if (!string.IsNullOrWhiteSpace(declaredMime))
            {
                var allowedMime = declaredMime.Equals("image/jpeg", StringComparison.OrdinalIgnoreCase)
                                  || declaredMime.Equals("image/png", StringComparison.OrdinalIgnoreCase)
                                  || declaredMime.Equals("image/webp", StringComparison.OrdinalIgnoreCase);
                if (!allowedMime)
                {
                    throw new UserException("Unsupported image type. Allowed: image/jpeg, image/png, image/webp.", HttpStatusCode.BadRequest);
                }
            }

            if (IsJpeg(bytes) || IsPng(bytes) || IsWebp(bytes))
            {
                return;
            }

            throw new UserException("Invalid image content. Supported formats are JPEG, PNG, and WEBP.", HttpStatusCode.BadRequest);
        }

        private static bool IsJpeg(byte[] bytes)
        {
            return bytes.Length >= 3
                   && bytes[0] == 0xFF
                   && bytes[1] == 0xD8
                   && bytes[2] == 0xFF;
        }

        private static bool IsPng(byte[] bytes)
        {
            return bytes.Length >= 8
                   && bytes[0] == 0x89
                   && bytes[1] == 0x50
                   && bytes[2] == 0x4E
                   && bytes[3] == 0x47
                   && bytes[4] == 0x0D
                   && bytes[5] == 0x0A
                   && bytes[6] == 0x1A
                   && bytes[7] == 0x0A;
        }

        private static bool IsWebp(byte[] bytes)
        {
            return bytes.Length >= 12
                   && bytes[0] == 0x52 // R
                   && bytes[1] == 0x49 // I
                   && bytes[2] == 0x46 // F
                   && bytes[3] == 0x46 // F
                   && bytes[8] == 0x57 // W
                   && bytes[9] == 0x45 // E
                   && bytes[10] == 0x42 // B
                   && bytes[11] == 0x50; // P
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
                throw new NotFoundException("Parking location not found");
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
                throw new NotFoundException("Parking location not found");
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

            Context.SaveChanges();
        }

        /// <summary>
        /// Content-Based Filtering (CBF) recommendation algorithm.
        /// Builds a user preference profile from completed reservations and bookmarks (bookmarks weighted 0.5×),
        /// then scores all active locations by:
        ///   - Feature similarity: 12 boolean amenities × 0.06 each (max 0.72)
        ///   - Price similarity: up to 0.15
        ///   - AverageRating: (rating/5) × 0.13
        ///   - Haversine distance bonus: up to 0.12 when lat/lon provided
        /// Fallback when user has no history: returns top-rated locations by AverageRating.
        /// Returns scores in [0.0, 1.0] range, up to <paramref name="count"/> results (default 3, max 10).
        /// </summary>
        public List<EasyPark.Model.Models.ParkingLocation> GetRecommendationScores(int userId, int? cityId = null, double? userLat = null, double? userLon = null, int count = 3)
        {
            int resultCount = Math.Clamp(count, 1, 10);
            var scoredLocations = new List<(ParkingLocationDb Location, decimal Score, string Explanation)>();

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

                var fallbackTop = fallbackLocations
                    .OrderByDescending(l => l.AverageRating)
                    .Take(resultCount)
                    .ToList();

                var fallbackResultList = new List<EasyPark.Model.Models.ParkingLocation>();
                foreach (var item in fallbackTop)
                {
                    var dto = Mapper.Map<EasyPark.Model.Models.ParkingLocation>(item);
                    dto.CbfScore = item.AverageRating > 0 ? Math.Round((item.AverageRating / 5.0m) * 100, 0) : 50;
                    dto.CbfExplanation = "Highly rated in your selected city";
                    fallbackResultList.Add(dto);
                }
                return fallbackResultList;
            }

            var userPreferredLocations = userReservations
                .Select(r => r.ParkingSpot.ParkingLocation)
                .GroupBy(l => l.Id)
                .Select(g => g.First())
                .ToList();

            // Load bookmarks and merge into profile with weight 0.5 (weaker signal than completed reservation).
            var bookmarkedLocationIds = Context.Set<BookmarkDb>()
                .Where(b => b.UserId == userId)
                .Select(b => b.ParkingLocationId)
                .ToList();

            var bookmarkedLocations = Context.Set<ParkingLocationDb>()
                .Include(pl => pl.ParkingSpots)
                .Where(pl => bookmarkedLocationIds.Contains(pl.Id))
                .ToList();

            int resCount = userPreferredLocations.Count;
            int bmkCount = bookmarkedLocations.Count;
            decimal totalWeight = resCount * 1.0m + bmkCount * 0.5m;

            decimal WeightedAvg(Func<ParkingLocationDb, decimal> selector) =>
                totalWeight == 0 ? 0 :
                (userPreferredLocations.Sum(l => selector(l) * 1.0m)
                 + bookmarkedLocations.Sum(l => selector(l) * 0.5m)) / totalWeight;

            var avgHasVideoSurveillance = WeightedAvg(l => l.HasVideoSurveillance ? 1.0m : 0.0m);
            var avgHasNightSurveillance = WeightedAvg(l => l.HasNightSurveillance ? 1.0m : 0.0m);
            var avgHasDisabledSpots = WeightedAvg(l => LocationHasActiveSpotType(l, "Disabled") ? 1.0m : 0.0m);
            var avgHasRamp = WeightedAvg(l => l.HasRamp ? 1.0m : 0.0m);
            var avgIs24Hours = WeightedAvg(l => l.Is24Hours ? 1.0m : 0.0m);
            var avgHasOnlinePayment = WeightedAvg(l => l.HasOnlinePayment ? 1.0m : 0.0m);
            var avgHasElectricCharging = WeightedAvg(l => LocationHasActiveSpotType(l, "Electric") ? 1.0m : 0.0m);
            var avgHasCoveredSpots = WeightedAvg(l => LocationHasActiveSpotType(l, "Covered") ? 1.0m : 0.0m);
            var avgHasSecurityGuard = WeightedAvg(l => l.HasSecurityGuard ? 1.0m : 0.0m);
            var avgHasWifi = WeightedAvg(l => l.HasWifi ? 1.0m : 0.0m);
            var avgHasRestroom = WeightedAvg(l => l.HasRestroom ? 1.0m : 0.0m);
            var avgHasAttendant = WeightedAvg(l => l.HasAttendant ? 1.0m : 0.0m);

            var allProfileLocations = userPreferredLocations.Concat(bookmarkedLocations).ToList();
            var avgPricePerHour = totalWeight == 0 ? 0.0
                : (userPreferredLocations.Sum(l => (double)l.PricePerHour * 1.0)
                   + bookmarkedLocations.Sum(l => (double)l.PricePerHour * 0.5)) / (double)totalWeight;

            var bookmarkedIdSet = new HashSet<int>(bookmarkedLocationIds);

            var locationQuery = Context.Set<ParkingLocationDb>()
                .Include(pl => pl.ParkingSpots)
                .Include(pl => pl.City)
                .Include(pl => pl.CreatedByUser)
                .Where(pl => pl.IsActive);

            if (cityId.HasValue)
                locationQuery = locationQuery.Where(pl => pl.CityId == cityId.Value);

            var allLocations = locationQuery.ToList();

            foreach (var location in allLocations)
            {
                decimal matchScore = 0.0m;
                var reasons = new List<string>();

                var matchedFeatures = new List<string>();
                if (Math.Abs((location.HasVideoSurveillance ? 1.0m : 0.0m) - avgHasVideoSurveillance) < 0.5m) { matchScore += 0.06m; if (location.HasVideoSurveillance) matchedFeatures.Add("Video Surveillance"); }
                if (Math.Abs((location.HasNightSurveillance ? 1.0m : 0.0m) - avgHasNightSurveillance) < 0.5m) { matchScore += 0.06m; if (location.HasNightSurveillance) matchedFeatures.Add("Night Surveillance"); }
                if (Math.Abs((LocationHasActiveSpotType(location, "Disabled") ? 1.0m : 0.0m) - avgHasDisabledSpots) < 0.5m) { matchScore += 0.06m; if (LocationHasActiveSpotType(location, "Disabled")) matchedFeatures.Add("Disabled Spots"); }
                if (Math.Abs((location.HasRamp ? 1.0m : 0.0m) - avgHasRamp) < 0.5m) { matchScore += 0.06m; if (location.HasRamp) matchedFeatures.Add("Ramp"); }
                if (Math.Abs((location.Is24Hours ? 1.0m : 0.0m) - avgIs24Hours) < 0.5m) { matchScore += 0.06m; if (location.Is24Hours) matchedFeatures.Add("24h"); }
                if (Math.Abs((location.HasOnlinePayment ? 1.0m : 0.0m) - avgHasOnlinePayment) < 0.5m) { matchScore += 0.06m; if (location.HasOnlinePayment) matchedFeatures.Add("Online Payment"); }
                if (Math.Abs((LocationHasActiveSpotType(location, "Electric") ? 1.0m : 0.0m) - avgHasElectricCharging) < 0.5m) { matchScore += 0.06m; if (LocationHasActiveSpotType(location, "Electric")) matchedFeatures.Add("EV Charging"); }
                if (Math.Abs((LocationHasActiveSpotType(location, "Covered") ? 1.0m : 0.0m) - avgHasCoveredSpots) < 0.5m) { matchScore += 0.06m; if (LocationHasActiveSpotType(location, "Covered")) matchedFeatures.Add("Covered Spots"); }
                if (Math.Abs((location.HasSecurityGuard ? 1.0m : 0.0m) - avgHasSecurityGuard) < 0.5m) { matchScore += 0.06m; if (location.HasSecurityGuard) matchedFeatures.Add("Security Guard"); }
                if (Math.Abs((location.HasWifi ? 1.0m : 0.0m) - avgHasWifi) < 0.5m) { matchScore += 0.06m; if (location.HasWifi) matchedFeatures.Add("WiFi"); }
                if (Math.Abs((location.HasRestroom ? 1.0m : 0.0m) - avgHasRestroom) < 0.5m) { matchScore += 0.06m; if (location.HasRestroom) matchedFeatures.Add("Restrooms"); }
                if (Math.Abs((location.HasAttendant ? 1.0m : 0.0m) - avgHasAttendant) < 0.5m) { matchScore += 0.06m; if (location.HasAttendant) matchedFeatures.Add("Attendant"); }

                var priceDiff = Math.Abs((double)location.PricePerHour - avgPricePerHour);
                var maxPrice = allProfileLocations.Count > 0 ? allProfileLocations.Max(l => (double)l.PricePerHour) : 0.0;
                var minPrice = allProfileLocations.Count > 0 ? allProfileLocations.Min(l => (double)l.PricePerHour) : 0.0;
                var priceRange = maxPrice - minPrice;
                if (priceRange > 0)
                {
                    var priceSimilarity = 1.0m - (decimal)(Math.Min(priceDiff / priceRange, 1.0));
                    matchScore += priceSimilarity * 0.15m;
                    if (priceSimilarity > 0.7m) reasons.Add("Price fits your preference");
                }
                else
                {
                    matchScore += 0.15m;
                    reasons.Add("Price fits your preference");
                }

                // AverageRating component (weight 0.13).
                decimal ratingScore = location.AverageRating > 0
                    ? (location.AverageRating / 5.0m) * 0.13m
                    : 0m;
                matchScore += ratingScore;

                if (location.AverageRating >= 4.0m)
                    reasons.Add($"Highly rated ({location.AverageRating:F1}★)");
                else if (location.AverageRating >= 3.0m)
                    reasons.Add($"Well rated ({location.AverageRating:F1}★)");
                else if (location.AverageRating > 0m)
                    reasons.Add($"Rated ({location.AverageRating:F1}★)");

                // Haversine distance bonus when user coordinates are provided.
                if (userLat.HasValue && userLon.HasValue
                    && location.Latitude != 0 && location.Longitude != 0)
                {
                    var km = HaversineDistance(userLat.Value, userLon.Value,
                                               (double)location.Latitude,
                                               (double)location.Longitude);
                    if (km <= 2) { matchScore += 0.12m; reasons.Add("Very close to you"); }
                    else if (km <= 5) { matchScore += 0.07m; reasons.Add("Near you"); }
                    else if (km <= 10) matchScore += 0.03m;
                }

                if (bookmarkedIdSet.Contains(location.Id))
                    reasons.Add("You bookmarked a similar location");

                if (matchedFeatures.Any())
                    reasons.Add("Has " + string.Join(", ", matchedFeatures.Take(2)));

                var normalizedScore = Math.Min(1.0m, Math.Max(0.0m, matchScore));

                string explanation = reasons.Any()
                    ? string.Join(". ", reasons) + "."
                    : "Good match based on your history.";

                scoredLocations.Add((location, normalizedScore, explanation));
            }

            var topN = scoredLocations.OrderByDescending(x => x.Score).Take(resultCount).ToList();
            var resultList = new List<EasyPark.Model.Models.ParkingLocation>();

            foreach (var item in topN)
            {
                var dto = Mapper.Map<EasyPark.Model.Models.ParkingLocation>(item.Location);
                dto.CbfScore = Math.Round(item.Score * 100, 0);
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
            if (from == default) from = DateTime.UtcNow.Date;
            if (to == default || to <= from) to = from.AddDays(1);
            if ((to - from).TotalDays > 7)
            {
                throw new UserException("Availability range cannot exceed 7 days.", HttpStatusCode.BadRequest);
            }

            var location = Context.ParkingLocations
                .Include(pl => pl.ParkingSpots)
                .FirstOrDefault(pl => pl.Id == locationId);
            if (location == null)
                throw new NotFoundException("Parking location not found");

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
                    .Select(r => new { r.ParkingSpotId, r.StartTime, r.EndTime })
                    .ToList();

                var intervals = reservations
                    .Select(r =>
                    {
                        var s = r.StartTime < from ? from : r.StartTime;
                        var e = r.EndTime > to ? to : r.EndTime;
                        return (r.ParkingSpotId, Start: s, End: e);
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

                    var overlapping = intervals
                        .Where(iv => iv.Start < segEnd && iv.End > segStart)
                        .Select(iv => iv.ParkingSpotId)
                        .Distinct()
                        .Count();
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

