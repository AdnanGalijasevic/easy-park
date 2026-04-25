using System;

namespace EasyPark.Model.Models
{
    public class AuthResponse
    {
        public required string AccessToken { get; set; }
        public required string RefreshToken { get; set; }
        public required DateTime AccessTokenExpiresAtUtc { get; set; }
        public required DateTime RefreshTokenExpiresAtUtc { get; set; }
        public required User User { get; set; }
    }
}
