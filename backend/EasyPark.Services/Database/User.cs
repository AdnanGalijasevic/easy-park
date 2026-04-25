using System;
using System.Collections.Generic;

namespace EasyPark.Services.Database
{
    public partial class User
    {
        public int Id { get; set; }

        public string FirstName { get; set; } = null!;

        public string LastName { get; set; } = null!;
        public string Username { get; set; } = null!;

        public string Email { get; set; } = null!;

        public string? Phone { get; set; }

        public string PasswordHash { get; set; } = null!;

        public string PasswordSalt { get; set; } = null!;

        public DateOnly BirthDate { get; set; }

        public bool IsActive { get; set; }

        public decimal Coins { get; set; }

        public DateTime CreatedAt { get; set; }

        public string? PasswordResetToken { get; set; }

        public DateTime? PasswordResetTokenExpiry { get; set; }

        public virtual ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
    }
}
