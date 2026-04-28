using System;
using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class ReservationInsertRequest
    {
        /// <summary>
        /// Optionally pre-select a specific spot. If null, the backend will
        /// auto-assign the first conflict-free spot of <see cref="SpotType"/>.
        /// </summary>
        public int? ParkingSpotId { get; set; }

        /// <summary>Spot type to reserve: Regular, Disabled, Electric, Covered.</summary>
        [StringLength(50)]
        public string? SpotType { get; set; }

        /// <summary>Required when ParkingSpotId is null so we know which location to search.</summary>
        public int? ParkingLocationId { get; set; }

        [Required]
        public DateTime StartTime { get; set; }

        [Required]
        public DateTime EndTime { get; set; }

        public TimeSpan? ExpectedDuration { get; set; }
        public bool CancellationAllowed { get; set; } = true;
    }
}
