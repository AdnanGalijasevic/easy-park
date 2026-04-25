namespace EasyPark.Model.Requests
{
    public class NotificationInsertRequest
    {
        public int UserId { get; set; }
        public string Title { get; set; } = null!;
        public string Message { get; set; } = null!;
        public string Type { get; set; } = null!;
    }

    public class NotificationUpdateRequest
    {
        public bool? IsRead { get; set; }
    }
}
