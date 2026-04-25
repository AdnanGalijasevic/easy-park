using System;

namespace EasyPark.Model.Models
{
    public class Report
    {
        public int Id { get; set; }
        public int? ParkingLocationId { get; set; }
        public string? ParkingLocationName { get; set; }
        public int? UserId { get; set; }
        public string? UserFullName { get; set; }
        public string ReportType { get; set; } = null!;
        public DateTime PeriodStart { get; set; }
        public DateTime PeriodEnd { get; set; }
        public decimal TotalRevenue { get; set; }
        public int TotalReservations { get; set; }
        public decimal? AverageRating { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}

