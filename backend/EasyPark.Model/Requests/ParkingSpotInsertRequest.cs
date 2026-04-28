using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class ParkingSpotInsertRequest
    {
        [Required]
        public int ParkingLocationId { get; set; }

        [Required]
        [StringLength(20)]
        public string SpotNumber { get; set; } = null!;

        [Required]
        [StringLength(50)]
        public string SpotType { get; set; } = null!;

        public bool IsActive { get; set; } = true;
        public bool IsOccupied { get; set; } = false;
    }
}
