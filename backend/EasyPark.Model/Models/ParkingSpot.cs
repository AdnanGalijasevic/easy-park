using System;

namespace EasyPark.Model.Models
{
    public class ParkingSpot
    {
        public int Id { get; set; }
        public int ParkingLocationId { get; set; }
        public string ParkingLocationName { get; set; } = null!;
        public string SpotNumber { get; set; } = null!;
        public string SpotType { get; set; } = null!;
        public bool IsActive { get; set; }
        public bool IsOccupied { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? NextReservationStart { get; set; }
        public DateTime? NextReservationEnd { get; set; }
    }
}

