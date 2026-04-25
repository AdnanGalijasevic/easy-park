using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface INotificationService : ICRUDService<Notification, NotificationSearchObject, NotificationInsertRequest, NotificationUpdateRequest>
    {
        void MarkAsRead(int id);
        void MarkAllAsReadForCurrentUser();
    }
}
