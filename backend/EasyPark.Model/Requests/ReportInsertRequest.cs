using System;

namespace EasyPark.Model.Requests
{
    public class ReportInsertRequest
    {
        public int? ParkingLocationId { get; set; }
        public string ReportType { get; set; } = null!;
        public DateTime PeriodStart { get; set; }
        public DateTime PeriodEnd { get; set; }
    }
}

