using System;

namespace EasyPark.Services.Helpers
{
    public class HashGenerator
    {
        private const string LegacyPrefix = "legacy-sha1";

        public static string GenerateSalt()
        {
            // BCrypt stores salt in the hash itself; keep a marker for old schema compatibility.
            return LegacyPrefix;
        }

        public static string GenerateHash(string salt, string password)
        {
            if (string.IsNullOrWhiteSpace(password))
                throw new ArgumentException("Password is required.", nameof(password));

            return BCrypt.Net.BCrypt.HashPassword(password);
        }

        public static bool Verify(string password, string storedHash, string? legacySalt = null)
        {
            if (string.IsNullOrWhiteSpace(password) || string.IsNullOrWhiteSpace(storedHash))
                return false;

            if (storedHash.StartsWith("$2", StringComparison.Ordinal))
            {
                return BCrypt.Net.BCrypt.Verify(password, storedHash);
            }

            // Legacy SHA1 fallback for seamless upgrade on login.
            if (!string.IsNullOrWhiteSpace(legacySalt))
            {
                using var algorithm = System.Security.Cryptography.SHA1.Create();
                var src = Convert.FromBase64String(legacySalt);
                var bytes = System.Text.Encoding.Unicode.GetBytes(password);
                var dst = new byte[src.Length + bytes.Length];
                Buffer.BlockCopy(src, 0, dst, 0, src.Length);
                Buffer.BlockCopy(bytes, 0, dst, src.Length, bytes.Length);
                var legacyHash = Convert.ToBase64String(algorithm.ComputeHash(dst));
                return legacyHash == storedHash;
            }

            return false;
        }
    }
}
