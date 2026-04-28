using System;
using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class UserInsertRequest
    {
        [Required]
        [StringLength(100)]
        public string FirstName { get; set; } = null!;

        [Required]
        [StringLength(100)]
        public string LastName { get; set; } = null!;

        [Required]
        [StringLength(100)]
        public string Username { get; set; } = null!;

        [Required]
        [EmailAddress]
        [StringLength(200)]
        public string Email { get; set; } = null!;

        [Required]
        [Phone]
        [StringLength(30)]
        public string Phone { get; set; } = null!;

        [Required]
        [MinLength(8)]
        [StringLength(128)]
        public string Password { get; set; } = null!;

        [Required]
        [MinLength(8)]
        [StringLength(128)]
        public string PasswordConfirm { get; set; } = null!;

        [Required]
        public DateOnly BirthDate { get; set; }
    }
}
