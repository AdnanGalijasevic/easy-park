using EasyPark.Model.SearchObjects;

namespace EasyPark.Model.SearchObjects
{
    public class NotificationSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }
        public bool? IsRead { get; set; }
    }
}
