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
using BookmarkModel = EasyPark.Model.Models.Bookmark;
using BookmarkDb = EasyPark.Services.Database.Bookmark;

namespace EasyPark.Services.Services
{
    public class BookmarkService : BaseCRUDService<BookmarkModel, BookmarkSearchObject, BookmarkDb, BookmarkInsertRequest, BookmarkUpdateRequest>, IBookmarkService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public BookmarkService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override IQueryable<BookmarkDb> AddFilter(BookmarkSearchObject search, IQueryable<BookmarkDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery
                .Include(b => b.User)
                .Include(b => b.ParkingLocation);

            if (search.ParkingLocationId.HasValue)
            {
                filteredQuery = filteredQuery.Where(b => b.ParkingLocationId == search.ParkingLocationId.Value);
            }

            if (CurrentUserHelper.IsAdmin(_httpContextAccessor) && search.UserId.HasValue)
            {
                filteredQuery = filteredQuery.Where(b => b.UserId == search.UserId.Value);
            }
            else if (!CurrentUserHelper.IsAdmin(_httpContextAccessor))
            {
                var uid = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
                filteredQuery = filteredQuery.Where(b => b.UserId == uid);
            }

            filteredQuery = filteredQuery.OrderByDescending(b => b.CreatedAt);

            return filteredQuery;
        }

        public override void BeforeInsert(BookmarkInsertRequest request, BookmarkDb entity)
        {
            var parkingLocation = Context.ParkingLocations.Find(request.ParkingLocationId);
            if (parkingLocation == null)
            {
                throw new UserException("Parking location not found", HttpStatusCode.NotFound);
            }

            var userId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            var existingBookmark = Context.Bookmarks
                .FirstOrDefault(b => b.UserId == userId && b.ParkingLocationId == request.ParkingLocationId);

            if (existingBookmark != null)
            {
                throw new UserException("You have already bookmarked this parking location", HttpStatusCode.BadRequest);
            }

            entity.UserId = userId;
            entity.CreatedAt = DateTime.UtcNow;
        }

        public override void BeforeUpdate(BookmarkUpdateRequest request, BookmarkDb entity)
        {
            // Bookmark doesn't have updatable fields
            throw new UserException("Bookmark cannot be updated", HttpStatusCode.BadRequest);
        }

        public override BookmarkModel GetById(int id)
        {
            var entity = Context.Set<BookmarkDb>()
                .Include(b => b.User)
                .Include(b => b.ParkingLocation)
                .FirstOrDefault(b => b.Id == id);

            if (entity == null)
            {
                throw new UserException("Bookmark not found", HttpStatusCode.NotFound);
            }

            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                entity.UserId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
            {
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            }

            return Mapper.Map<BookmarkModel>(entity);
        }

        public override void Delete(int id)
        {
            var entity = Context.Set<BookmarkDb>().Find(id);
            if (entity == null)
                return;
            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                entity.UserId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            base.Delete(id);
        }

        public override PagedResult<BookmarkModel> GetPaged(BookmarkSearchObject search)
        {
            var result = new List<BookmarkModel>();

            var query = Context.Set<BookmarkDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();

            result = Mapper.Map(list, result);

            var pagedResult = new PagedResult<BookmarkModel>();
            pagedResult.ResultList = result;
            pagedResult.Count = count;

            return pagedResult;
        }

        public override BookmarkModel Insert(BookmarkInsertRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);

            var entity = Mapper.Map<BookmarkDb>(request);
            BeforeInsert(request, entity);

            Context.Bookmarks.Add(entity);
            Context.SaveChanges();

            var hydrated = Context.Bookmarks
                .Include(b => b.User)
                .Include(b => b.ParkingLocation)
                .FirstOrDefault(b => b.Id == entity.Id)
                ?? throw new UserException("Bookmark not found after insert", HttpStatusCode.InternalServerError);

            return Mapper.Map<BookmarkModel>(hydrated);
        }

    }
}

