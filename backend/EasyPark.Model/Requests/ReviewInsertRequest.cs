using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class ReviewInsertRequest
    {
        [Required]
        public int ParkingLocationId { get; set; }

        [Required]
        [Range(1, 5)]
        public int Rating { get; set; }

        [StringLength(1000)]
        public string? Comment { get; set; }
    }
}
