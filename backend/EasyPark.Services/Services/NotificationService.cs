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
using NotificationModel = EasyPark.Model.Models.Notification;
using NotificationDb = EasyPark.Services.Database.Notification;

namespace EasyPark.Services.Services
{
    public class NotificationService : BaseCRUDService<NotificationModel, NotificationSearchObject, NotificationDb, NotificationInsertRequest, NotificationUpdateRequest>, INotificationService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public NotificationService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override IQueryable<NotificationDb> AddFilter(NotificationSearchObject search, IQueryable<NotificationDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            if (CurrentUserHelper.IsAdmin(_httpContextAccessor) && search.UserId.HasValue)
            {
                filteredQuery = filteredQuery.Where(n => n.UserId == search.UserId.Value);
            }
            else if (!CurrentUserHelper.IsAdmin(_httpContextAccessor))
            {
                var uid = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
                filteredQuery = filteredQuery.Where(n => n.UserId == uid);
            }

            if (search.IsRead.HasValue)
            {
                filteredQuery = filteredQuery.Where(n => n.IsRead == search.IsRead.Value);
            }

            return filteredQuery.OrderByDescending(n => n.CreatedAt);
        }

        public override NotificationModel GetById(int id)
        {
            var entity = Context.Notifications.AsNoTracking().FirstOrDefault(n => n.Id == id);
            if (entity == null)
                throw new UserException("Notification not found", HttpStatusCode.NotFound);

            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                entity.UserId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
            {
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            }

            return Mapper.Map<NotificationModel>(entity);
        }

        public override void BeforeInsert(NotificationInsertRequest request, NotificationDb entity)
        {
            entity.CreatedAt = DateTime.UtcNow;
            entity.IsRead = false;
        }

        public void MarkAsRead(int id)
        {
            var entity = Context.Notifications.Find(id);
            if (entity == null)
                throw new UserException("Notification not found", HttpStatusCode.NotFound);

            var uid = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) && entity.UserId != uid)
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);

            entity.IsRead = true;
            Context.SaveChanges();
        }

        public void MarkAllAsReadForCurrentUser()
        {
            var uid = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            var unread = Context.Notifications.Where(n => n.UserId == uid && !n.IsRead).ToList();
            foreach (var n in unread)
            {
                n.IsRead = true;
            }
            Context.SaveChanges();
        }
    }
}
