using System;

namespace EasyPark.Services.Database
{
    public partial class Report
    {
        public int Id { get; set; }
        public int? ParkingLocationId { get; set; }
        public int? UserId { get; set; }
        public string ReportType { get; set; } = null!;
        public DateTime PeriodStart { get; set; }
        public DateTime PeriodEnd { get; set; }
        public decimal TotalRevenue { get; set; }
        public int TotalReservations { get; set; }
        public decimal? AverageRating { get; set; }
        public DateTime CreatedAt { get; set; }

        public virtual ParkingLocation? ParkingLocation { get; set; }
        public virtual User? User { get; set; }
    }
}

