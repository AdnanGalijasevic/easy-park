using System;

namespace EasyPark.Model.Models
{
    public class Reservation
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string UserFullName { get; set; } = null!;
        public int ParkingSpotId { get; set; }
        public string ParkingSpotNumber { get; set; } = null!;
        public string? SpotType { get; set; }
        public int? ParkingLocationId { get; set; }
        public string ParkingLocationName { get; set; } = null!;
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public TimeSpan? ExpectedDuration { get; set; }
        public decimal TotalPrice { get; set; }
        public string Status { get; set; } = null!; // "Pending", "Active", "Completed", "Cancelled", "Expired"
        public string? QRCode { get; set; }
        public bool CancellationAllowed { get; set; }
        public string? CancellationReason { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}

