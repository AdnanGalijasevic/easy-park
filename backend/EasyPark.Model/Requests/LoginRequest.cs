using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class LoginRequest
    {
        [Required]
        [StringLength(100)]
        public string username { get; set; } = null!;

        [Required]
        [StringLength(128)]
        public string password { get; set; } = null!;
    }
}
