using System;

namespace EasyPark.Services.Database
{
    public partial class Review
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int ParkingLocationId { get; set; }
        public int Rating { get; set; } // 1-5
        public string? Comment { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public virtual User User { get; set; } = null!;
        public virtual ParkingLocation ParkingLocation { get; set; } = null!;
    }
}

