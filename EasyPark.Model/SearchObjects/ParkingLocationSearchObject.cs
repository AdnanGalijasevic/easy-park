using System;

namespace EasyPark.Model.SearchObjects
{
    public class ParkingLocationSearchObject : BaseSearchObject
    {
        public string? FTS { get; set; }
        public string? City { get; set; }
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public decimal? MaxDistance { get; set; } // in kilometers
        public decimal? MinPricePerHour { get; set; }
        public decimal? MaxPricePerHour { get; set; }
        public bool? IsActive { get; set; }
        public bool? HasVideoSurveillance { get; set; }
        public bool? HasDisabledSpots { get; set; }
        public bool? Is24Hours { get; set; }
        public bool? HasOnlinePayment { get; set; }
        public bool? HasElectricCharging { get; set; }
        public bool? HasCoveredSpots { get; set; }
        public string? ParkingType { get; set; }
    }
}

