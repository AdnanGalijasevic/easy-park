using System;

namespace EasyPark.Model.Models
{
    public class Bookmark
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string UserFullName { get; set; } = null!;
        public int ParkingLocationId { get; set; }
        public string ParkingLocationName { get; set; } = null!;
        public DateTime CreatedAt { get; set; }
    }
}

