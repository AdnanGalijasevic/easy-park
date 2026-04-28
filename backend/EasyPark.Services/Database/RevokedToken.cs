using System;

namespace EasyPark.Services.Database
{
    public class RevokedToken
    {
        public int Id { get; set; }
        public string Jti { get; set; } = null!;
        public DateTime RevokedAt { get; set; }
        public DateTime ExpiresAt { get; set; }
    }
}
