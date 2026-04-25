using System;

namespace EasyPark.Model.SearchObjects
{
    public class ReservationSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }
        public int? ParkingSpotId { get; set; }
        public int? ParkingLocationId { get; set; }
        public string? Status { get; set; }
        public DateTime? StartTimeFrom { get; set; }
        public DateTime? StartTimeTo { get; set; }
        public DateTime? EndTimeFrom { get; set; }
        public DateTime? EndTimeTo { get; set; }
        public bool? CancellationAllowed { get; set; }
    }
}

