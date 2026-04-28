using System;

namespace EasyPark.Model.Requests
{
    public class ParkingLocationUpdateRequest
    {
        public string? Name { get; set; }
        public string? Address { get; set; }
        public int? CityId { get; set; }
        public string? PostalCode { get; set; }
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public string? Description { get; set; }
        public decimal? PricePerHour { get; set; }
        public decimal? PricePerDay { get; set; }
        public string? Photo { get; set; }
        
        public bool? IsActive { get; set; }

        public bool? HasVideoSurveillance { get; set; }
        public bool? HasNightSurveillance { get; set; }
        public bool? HasDisabledSpots { get; set; }
        public bool? HasRamp { get; set; }
        public bool? Is24Hours { get; set; }
        public bool? HasOnlinePayment { get; set; }
        public bool? HasElectricCharging { get; set; }
        public bool? HasCoveredSpots { get; set; }
        public bool? HasSecurityGuard { get; set; }
        public bool? HasWifi { get; set; }
        public bool? HasRestroom { get; set; }
        public bool? HasAttendant { get; set; }
        
        public decimal? MaxVehicleHeight { get; set; }
        public decimal? DistanceFromCenter { get; set; }
        public string? ParkingType { get; set; }
        public string? OperatingHours { get; set; }
        public decimal? SafetyRating { get; set; }
        public decimal? CleanlinessRating { get; set; }
        public decimal? AccessibilityRating { get; set; }
        public DateTime? LastMaintenanceDate { get; set; }
        public string? PaymentOptions { get; set; }
    }
}
