using System;

namespace EasyPark.Services.Database
{
    public partial class Bookmark
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int ParkingLocationId { get; set; }
        public DateTime CreatedAt { get; set; }

        // Navigation properties
        public virtual User User { get; set; } = null!;
        public virtual ParkingLocation ParkingLocation { get; set; } = null!;
    }
}

