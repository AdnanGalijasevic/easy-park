using System;

namespace EasyPark.Model.Models
{
    public class ParkingLocation
    {
        public int Id { get; set; }
        public string Name { get; set; } = null!;
        public string Address { get; set; } = null!;
        public int CityId { get; set; }
        public string CityName { get; set; } = null!;
        public string? PostalCode { get; set; }
        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
        public string? Description { get; set; }
        public int TotalSpots { get; set; }
        public decimal PricePerHour { get; set; }
        public decimal? PricePerDay { get; set; }
        public decimal PriceRegular { get; set; }
        public decimal PriceDisabled { get; set; }
        public decimal PriceElectric { get; set; }
        public decimal PriceCovered { get; set; }
        public string? Photo { get; set; }
        public int CreatedBy { get; set; }
        public string CreatedByName { get; set; } = null!;
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public bool IsActive { get; set; }

        // Attributes for Recommendation System
        public bool HasVideoSurveillance { get; set; }
        public bool HasNightSurveillance { get; set; }
        public bool HasDisabledSpots { get; set; }
        public bool HasRamp { get; set; }
        public bool Is24Hours { get; set; }
        public bool HasOnlinePayment { get; set; }
        public bool HasElectricCharging { get; set; }
        public bool HasCoveredSpots { get; set; }
        public bool HasSecurityGuard { get; set; }
        public decimal? MaxVehicleHeight { get; set; }
        public decimal AverageRating { get; set; }
        public int TotalReviews { get; set; }
        public decimal? DistanceFromCenter { get; set; }
        public string? ParkingType { get; set; }
        public string? OperatingHours { get; set; }
        public decimal? SafetyRating { get; set; }
        public decimal? CleanlinessRating { get; set; }
        public decimal? AccessibilityRating { get; set; }
        public decimal? PopularityScore { get; set; }
        public DateTime? LastMaintenanceDate { get; set; }
        public bool HasWifi { get; set; }
        public bool HasRestroom { get; set; }
        public bool HasAttendant { get; set; }
        public string? PaymentOptions { get; set; }
        public System.Collections.Generic.IList<ParkingSpot>? ParkingSpots { get; set; }
        
        public decimal? CbfScore { get; set; }
        public string? CbfExplanation { get; set; }
    }
}

