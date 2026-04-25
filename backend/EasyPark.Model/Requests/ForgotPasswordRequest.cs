using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class ForgotPasswordRequest
    {
        [Required]
        public string EmailOrUsername { get; set; } = string.Empty;
    }
}
