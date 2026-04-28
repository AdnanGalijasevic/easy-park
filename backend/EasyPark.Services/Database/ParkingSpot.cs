using System;
using System.Collections.Generic;

namespace EasyPark.Services.Database
{
    public partial class ParkingSpot
    {
        public int Id { get; set; }
        public int ParkingLocationId { get; set; }
        public string SpotNumber { get; set; } = null!;
        public string SpotType { get; set; } = null!; // "Regular", "Disabled", "Electric", "Covered"
        public bool IsActive { get; set; } = true;
        public bool IsOccupied { get; set; } = false;
        public DateTime CreatedAt { get; set; }

        public virtual ParkingLocation ParkingLocation { get; set; } = null!;
        public virtual ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    }
}

