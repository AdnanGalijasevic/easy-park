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
using ReviewModel = EasyPark.Model.Models.Review;
using ReviewDb = EasyPark.Services.Database.Review;

namespace EasyPark.Services.Services
{
    public class ReviewService : BaseCRUDService<ReviewModel, ReviewSearchObject, ReviewDb, ReviewInsertRequest, ReviewUpdateRequest>, IReviewService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ReviewService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override IQueryable<ReviewDb> AddFilter(ReviewSearchObject search, IQueryable<ReviewDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery
                .Include(r => r.User)
                .Include(r => r.ParkingLocation);

            if (search.UserId.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.UserId == search.UserId.Value);
            }

            if (search.ParkingLocationId.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.ParkingLocationId == search.ParkingLocationId.Value);
            }

            if (search.Rating.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.Rating == search.Rating.Value);
            }

            if (search.MinRating.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.Rating >= search.MinRating.Value);
            }

            if (search.MaxRating.HasValue)
            {
                filteredQuery = filteredQuery.Where(r => r.Rating <= search.MaxRating.Value);
            }

            filteredQuery = filteredQuery.OrderByDescending(r => r.CreatedAt);

            return filteredQuery;
        }

        public override void BeforeInsert(ReviewInsertRequest request, ReviewDb entity)
        {
            if (request.Rating < 1 || request.Rating > 5)
            {
                throw new UserException("Rating must be between 1 and 5", HttpStatusCode.BadRequest);
            }

            var parkingLocation = Context.ParkingLocations.Find(request.ParkingLocationId);
            if (parkingLocation == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            var userId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            var existingReview = Context.Reviews
                .FirstOrDefault(r => r.UserId == userId && r.ParkingLocationId == request.ParkingLocationId);

            if (existingReview != null)
            {
                throw new UserException("You have already reviewed this parking location", HttpStatusCode.BadRequest);
            }

            entity.UserId = userId;
            entity.CreatedAt = DateTime.UtcNow;
        }

        public override void BeforeUpdate(ReviewUpdateRequest request, ReviewDb entity)
        {
            if (entity == null)
            {
                throw new UserException("Review not found", HttpStatusCode.NotFound);
            }

            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                entity.UserId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
            {
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            }

            if (request.Rating.HasValue)
            {
                if (request.Rating.Value < 1 || request.Rating.Value > 5)
                {
                    throw new UserException("Rating must be between 1 and 5", HttpStatusCode.BadRequest);
                }
            }

            entity.UpdatedAt = DateTime.UtcNow;
        }

        public override ReviewModel GetById(int id)
        {
            var entity = Context.Set<ReviewDb>()
                .Include(r => r.User)
                .Include(r => r.ParkingLocation)
                .FirstOrDefault(r => r.Id == id);

            if (entity == null)
            {
                throw new UserException("Review not found", HttpStatusCode.NotFound);
            }

            return Mapper.Map<ReviewModel>(entity);
        }

        public override PagedResult<ReviewModel> GetPaged(ReviewSearchObject search)
        {
            var result = new List<ReviewModel>();

            var query = Context.Set<ReviewDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();

            result = Mapper.Map(list, result);

            var pagedResult = new PagedResult<ReviewModel>();
            pagedResult.ResultList = result;
            pagedResult.Count = count;

            return pagedResult;
        }

        public override ReviewModel Insert(ReviewInsertRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);

            var entity = Mapper.Map<ReviewDb>(request);
            BeforeInsert(request, entity);

            Context.Reviews.Add(entity);
            Context.SaveChanges();

            UpdateParkingLocationRating(request.ParkingLocationId);

            var hydrated = Context.Reviews
                .Include(r => r.User)
                .Include(r => r.ParkingLocation)
                .FirstOrDefault(r => r.Id == entity.Id)
                ?? throw new UserException("Review not found after insert", HttpStatusCode.InternalServerError);

            return Mapper.Map<ReviewModel>(hydrated);
        }

        public override ReviewModel Update(int id, ReviewUpdateRequest request)
        {
            var entity = Context.Reviews
                .Include(r => r.User)
                .Include(r => r.ParkingLocation)
                .FirstOrDefault(r => r.Id == id);
            if (entity == null)
            {
                throw new UserException("Review not found", HttpStatusCode.NotFound);
            }

            var parkingLocationId = entity.ParkingLocationId;
            BeforeUpdate(request, entity);
            Mapper.Map(request, entity);
            Context.SaveChanges();

            UpdateParkingLocationRating(parkingLocationId);

            var hydrated = Context.Reviews
                .Include(r => r.User)
                .Include(r => r.ParkingLocation)
                .FirstOrDefault(r => r.Id == id)
                ?? throw new UserException("Review not found after update", HttpStatusCode.InternalServerError);

            return Mapper.Map<ReviewModel>(hydrated);
        }

        private void UpdateParkingLocationRating(int parkingLocationId)
        {
            var reviews = Context.Reviews
                .Where(r => r.ParkingLocationId == parkingLocationId)
                .ToList();

            if (reviews.Any())
            {
                var averageRating = reviews.Average(r => (decimal)r.Rating);
                var totalReviews = reviews.Count;

                var parkingLocation = Context.ParkingLocations.Find(parkingLocationId);
                if (parkingLocation != null)
                {
                    parkingLocation.AverageRating = Math.Round(averageRating, 2);
                    parkingLocation.TotalReviews = totalReviews;
                    Context.SaveChanges();
                }
            }
        }

    }
}

