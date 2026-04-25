using System;

namespace EasyPark.Model.Messages
{
    public class ReservationEndingSoon
    {
        public int ReservationId { get; set; }
        public string Email { get; set; } = null!;
        public string Name { get; set; } = null!;
        public string ParkingLocationName { get; set; } = null!;
        public string SpotNumber { get; set; } = null!;
        public DateTime EndTime { get; set; }
    }
}
