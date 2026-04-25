using System;

namespace EasyPark.Model.Models
{
    public class Review
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string UserFullName { get; set; } = null!;
        public int ParkingLocationId { get; set; }
        public string ParkingLocationName { get; set; } = null!;
        public int Rating { get; set; } // 1-5
        public string? Comment { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}

