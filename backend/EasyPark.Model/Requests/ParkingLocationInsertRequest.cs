using System;
using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class ParkingLocationInsertRequest
    {
        [Required]
        [StringLength(200)]
        public string Name { get; set; } = null!;

        [Required]
        [StringLength(300)]
        public string Address { get; set; } = null!;

        [Required]
        public int CityId { get; set; }

        [Required]
        [Range(-90.0, 90.0)]
        public decimal Latitude { get; set; }

        [Required]
        [Range(-180.0, 180.0)]
        public decimal Longitude { get; set; }

        [Required]
        [Range(0.0, 10000.0)]
        public decimal PricePerHour { get; set; }

        [Required]
        [Range(0.0, 10000.0)]
        public decimal PriceRegular { get; set; }

        [Required]
        [Range(0.0, 10000.0)]
        public decimal PriceDisabled { get; set; }

        [Required]
        [Range(0.0, 10000.0)]
        public decimal PriceElectric { get; set; }

        [Required]
        [Range(0.0, 10000.0)]
        public decimal PriceCovered { get; set; }

        public string? Photo { get; set; }

        [StringLength(20)]
        public string? PostalCode { get; set; }

        [StringLength(1000)]
        public string? Description { get; set; }

        [Range(0.0, 10000.0)]
        public decimal? PricePerDay { get; set; }

        public bool HasVideoSurveillance { get; set; }
        public bool HasNightSurveillance { get; set; }
        public bool HasRamp { get; set; }
        public bool Is24Hours { get; set; }
        public bool HasOnlinePayment { get; set; }
        public bool HasSecurityGuard { get; set; }
        public bool HasWifi { get; set; }
        public bool HasRestroom { get; set; }
        public bool HasAttendant { get; set; }

        [Range(0.0, 20.0)]
        public decimal? MaxVehicleHeight { get; set; }

        [Range(0.0, 100.0)]
        public decimal? DistanceFromCenter { get; set; }

        [StringLength(50)]
        public string? ParkingType { get; set; }

        [StringLength(200)]
        public string? OperatingHours { get; set; }

        [Range(0.0, 5.0)]
        public decimal? SafetyRating { get; set; }

        [Range(0.0, 5.0)]
        public decimal? CleanlinessRating { get; set; }

        [Range(0.0, 5.0)]
        public decimal? AccessibilityRating { get; set; }

        public DateTime? LastMaintenanceDate { get; set; }

        [StringLength(200)]
        public string? PaymentOptions { get; set; }
    }
}
