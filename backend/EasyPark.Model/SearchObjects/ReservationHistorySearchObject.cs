using System;

namespace EasyPark.Model.SearchObjects
{
    public class ReservationHistorySearchObject : BaseSearchObject
    {
        public int? ReservationId { get; set; }
        public int? UserId { get; set; }
        public int? ParkingLocationId { get; set; }
        public string? OldStatus { get; set; }
        public string? NewStatus { get; set; }
        public DateTime? ChangedFrom { get; set; }
        public DateTime? ChangedTo { get; set; }
    }
}

