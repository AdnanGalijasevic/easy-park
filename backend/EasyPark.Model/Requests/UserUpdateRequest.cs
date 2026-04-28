using System;
using System.ComponentModel.DataAnnotations;

namespace EasyPark.Model.Requests
{
    public class UserUpdateRequest
    {
        [StringLength(100)]
        public string? FirstName { get; set; }

        [StringLength(100)]
        public string? LastName { get; set; }

        [StringLength(100)]
        public string? Username { get; set; }

        [EmailAddress]
        [StringLength(200)]
        public string? Email { get; set; }

        [Phone]
        [StringLength(30)]
        public string? Phone { get; set; }

        [StringLength(128)]
        public string? CurrentPassword { get; set; }

        [MinLength(8)]
        [StringLength(128)]
        public string? NewPassword { get; set; }

        [MinLength(8)]
        [StringLength(128)]
        public string? NewPasswordConfirm { get; set; }

        public DateOnly? BirthDate { get; set; }
    }
}
