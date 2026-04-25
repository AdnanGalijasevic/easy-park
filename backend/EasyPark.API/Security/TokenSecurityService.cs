using System.Collections.Concurrent;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using EasyPark.Model.Models;
using Microsoft.IdentityModel.Tokens;

namespace EasyPark.API.Security
{
    public interface ITokenSecurityService
    {
        AuthResponse CreateAuthResponse(User user);
        bool TryRotateRefreshToken(string refreshToken, out int userId);
        void RevokeRefreshToken(string refreshToken);
        void RevokeJwt(string jwtToken);
        bool IsJwtRevoked(string jwtToken);
    }

    public class TokenSecurityService : ITokenSecurityService
    {
        private readonly JwtSecurityTokenHandler _jwtHandler = new();
        private readonly ConcurrentDictionary<string, DateTime> _revokedJwtJtis = new();
        private readonly ConcurrentDictionary<string, RefreshTokenState> _refreshTokens = new();
        private readonly byte[] _jwtKeyBytes;
        private readonly string _issuer;
        private readonly string _audience;
        private readonly int _accessTokenExpiryMinutes;
        private readonly int _refreshTokenExpiryDays;

        public TokenSecurityService(IConfiguration configuration)
        {
            var jwtKey = Environment.GetEnvironmentVariable("_jwtKey") ?? configuration["Jwt:Key"];
            _issuer = Environment.GetEnvironmentVariable("_jwtIssuer") ?? configuration["Jwt:Issuer"] ?? "easypark-api";
            _audience = Environment.GetEnvironmentVariable("_jwtAudience") ?? configuration["Jwt:Audience"] ?? "easypark-clients";

            if (!int.TryParse(Environment.GetEnvironmentVariable("_jwtExpirationMinutes") ?? configuration["Jwt:ExpirationMinutes"], out _accessTokenExpiryMinutes))
            {
                _accessTokenExpiryMinutes = 60;
            }

            if (!int.TryParse(Environment.GetEnvironmentVariable("_refreshTokenExpirationDays") ?? configuration["Jwt:RefreshTokenExpirationDays"], out _refreshTokenExpiryDays))
            {
                _refreshTokenExpiryDays = 7;
            }

            if (string.IsNullOrWhiteSpace(jwtKey))
            {
                throw new InvalidOperationException("JWT key is not configured. Set '_jwtKey' env var or 'Jwt:Key' config.");
            }

            _jwtKeyBytes = Encoding.UTF8.GetBytes(jwtKey);
        }

        public AuthResponse CreateAuthResponse(User user)
        {
            var now = DateTime.UtcNow;
            var jwtExpiry = now.AddMinutes(_accessTokenExpiryMinutes);
            var refreshExpiry = now.AddDays(_refreshTokenExpiryDays);
            var refreshToken = GenerateRefreshToken();

            var claims = new List<Claim>
            {
                new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new(ClaimTypes.Name, user.FirstName),
                new("Username", user.Username),
                new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            foreach (var role in user.Roles)
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }

            var descriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = jwtExpiry,
                Issuer = _issuer,
                Audience = _audience,
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(_jwtKeyBytes), SecurityAlgorithms.HmacSha256Signature)
            };

            var jwt = _jwtHandler.CreateToken(descriptor);
            var accessToken = _jwtHandler.WriteToken(jwt);
            _refreshTokens[refreshToken] = new RefreshTokenState(user.Id, refreshExpiry);

            CleanupExpiredEntries();

            return new AuthResponse
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken,
                AccessTokenExpiresAtUtc = jwtExpiry,
                RefreshTokenExpiresAtUtc = refreshExpiry,
                User = user
            };
        }

        public bool TryRotateRefreshToken(string refreshToken, out int userId)
        {
            userId = 0;

            if (!_refreshTokens.TryGetValue(refreshToken, out var state) || state.ExpiresAtUtc <= DateTime.UtcNow || state.IsRevoked)
            {
                return false;
            }

            userId = state.UserId;
            state.IsRevoked = true;
            _refreshTokens[refreshToken] = state;
            return true;
        }

        public void RevokeRefreshToken(string refreshToken)
        {
            if (_refreshTokens.TryGetValue(refreshToken, out var state))
            {
                state.IsRevoked = true;
                _refreshTokens[refreshToken] = state;
            }
        }

        public void RevokeJwt(string jwtToken)
        {
            var token = _jwtHandler.ReadJwtToken(jwtToken);
            var jti = token.Claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Jti)?.Value;
            if (string.IsNullOrWhiteSpace(jti))
            {
                return;
            }

            var exp = token.ValidTo == DateTime.MinValue ? DateTime.UtcNow.AddHours(1) : token.ValidTo.ToUniversalTime();
            _revokedJwtJtis[jti] = exp;
        }

        public bool IsJwtRevoked(string jwtToken)
        {
            var token = _jwtHandler.ReadJwtToken(jwtToken);
            var jti = token.Claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Jti)?.Value;
            if (string.IsNullOrWhiteSpace(jti))
            {
                return false;
            }

            if (_revokedJwtJtis.TryGetValue(jti, out var revokedUntil) && revokedUntil > DateTime.UtcNow)
            {
                return true;
            }

            return false;
        }

        private static string GenerateRefreshToken()
        {
            var randomBytes = RandomNumberGenerator.GetBytes(64);
            return Convert.ToBase64String(randomBytes);
        }

        private void CleanupExpiredEntries()
        {
            var now = DateTime.UtcNow;
            foreach (var entry in _revokedJwtJtis.Where(x => x.Value <= now).ToList())
            {
                _revokedJwtJtis.TryRemove(entry.Key, out _);
            }

            foreach (var entry in _refreshTokens.Where(x => x.Value.ExpiresAtUtc <= now).ToList())
            {
                _refreshTokens.TryRemove(entry.Key, out _);
            }
        }

        private record struct RefreshTokenState(int UserId, DateTime ExpiresAtUtc)
        {
            public bool IsRevoked { get; set; }
        }
    }
}
