using System;

namespace EasyPark.Model.Models
{
    public class ReservationHistory
    {
        public int Id { get; set; }
        public int ReservationId { get; set; }
        public int? UserId { get; set; }
        public string? UserFullName { get; set; }
        public string? OldStatus { get; set; }
        public string? NewStatus { get; set; }
        public string? ChangeReason { get; set; }
        public DateTime ChangedAt { get; set; }
        public string? Notes { get; set; }
    }
}

