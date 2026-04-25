using System;

namespace EasyPark.Model.Messages
{
    public class ReservationCompleted
    {
        public int ReservationId { get; set; }
        public string Email { get; set; } = null!;
        public string Name { get; set; } = null!;
        public string ParkingLocationName { get; set; } = null!;
        public string SpotNumber { get; set; } = null!;
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public decimal TotalPrice { get; set; }
    }
}

