using System.Net;
using System.Security.Claims;
using EasyPark.Model;
using Microsoft.AspNetCore.Http;

namespace EasyPark.Services.Helpers
{
    public static class CurrentUserHelper
    {
        public static int GetRequiredUserId(IHttpContextAccessor httpContextAccessor)
        {
            var principal = httpContextAccessor.HttpContext?.User;
            var id = principal?.FindFirst("UserId")?.Value
                ?? principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(id) || !int.TryParse(id, out var userId))
                throw new UserException("User not authenticated", HttpStatusCode.Unauthorized);
            return userId;
        }

        public static int? TryGetUserId(IHttpContextAccessor httpContextAccessor)
        {
            var principal = httpContextAccessor.HttpContext?.User;
            var id = principal?.FindFirst("UserId")?.Value
                ?? principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(id) || !int.TryParse(id, out var userId))
                return null;
            return userId;
        }

        public static bool IsAdmin(IHttpContextAccessor httpContextAccessor)
        {
            return httpContextAccessor.HttpContext?.User?.IsInRole("Admin") == true;
        }
    }
}
