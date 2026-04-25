using System;
using System.Collections.Generic;

namespace EasyPark.Services.Database
{
    public partial class Reservation
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int ParkingSpotId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public TimeSpan? ExpectedDuration { get; set; }
        public decimal TotalPrice { get; set; }
        public string Status { get; set; } = null!; // "Pending", "Active", "Completed", "Cancelled", "Expired"
        public string? QRCode { get; set; }
        public bool CancellationAllowed { get; set; } = true;
        public string? CancellationReason { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public bool EndingSoonNotificationSent { get; set; } = false;

        // Navigation properties
        public virtual User User { get; set; } = null!;
        public virtual ParkingSpot ParkingSpot { get; set; } = null!;
        public virtual Transaction? Transaction { get; set; }
        public virtual ICollection<ReservationHistory> ReservationHistories { get; set; } = new List<ReservationHistory>();
    }
}

