using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using Microsoft.Extensions.DependencyInjection;

namespace EasyPark.Services.Services
{
    public class TokenRevocationStore : ITokenRevocationStore
    {
        private readonly IServiceScopeFactory _scopeFactory;

        public TokenRevocationStore(IServiceScopeFactory scopeFactory)
        {
            _scopeFactory = scopeFactory;
        }

        public void Revoke(string jti, DateTime expiresAt)
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<EasyParkDbContext>();

            if (!db.RevokedTokens.Any(r => r.Jti == jti))
            {
                db.RevokedTokens.Add(new RevokedToken
                {
                    Jti = jti,
                    RevokedAt = DateTime.UtcNow,
                    ExpiresAt = expiresAt
                });
                db.SaveChanges();
            }
        }

        public bool IsRevoked(string jti)
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<EasyParkDbContext>();
            return db.RevokedTokens.Any(r => r.Jti == jti && r.ExpiresAt > DateTime.UtcNow);
        }

        public void DeleteExpired()
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<EasyParkDbContext>();
            var expired = db.RevokedTokens.Where(r => r.ExpiresAt <= DateTime.UtcNow).ToList();
            if (expired.Count > 0)
            {
                db.RevokedTokens.RemoveRange(expired);
                db.SaveChanges();
            }
        }
    }
}
