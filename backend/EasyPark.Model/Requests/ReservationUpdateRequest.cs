using System;

namespace EasyPark.Model.Requests
{
    public class ReservationUpdateRequest
    {
        public DateTime? StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TimeSpan? ExpectedDuration { get; set; }
        public string? Status { get; set; }
        public bool? CancellationAllowed { get; set; }
        public string? CancellationReason { get; set; }
    }
}

