using System;

namespace EasyPark.Model.Models
{
    public class Notification
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string Title { get; set; } = null!;
        public string Message { get; set; } = null!;
        public string Type { get; set; } = null!; // "Info", "Alert", "Success"
        public bool IsRead { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
