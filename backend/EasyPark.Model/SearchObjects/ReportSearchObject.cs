using System;

namespace EasyPark.Model.SearchObjects
{
    public class ReportSearchObject : BaseSearchObject
    {
        public int? ParkingLocationId { get; set; }
        public int? UserId { get; set; }
        public string? ReportType { get; set; }
        public DateTime? PeriodStartFrom { get; set; }
        public DateTime? PeriodStartTo { get; set; }
    }
}

