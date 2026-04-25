using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Moq;

namespace EasyPark.Tests
{
    public static class TestClaimsHelper
    {
        public static IHttpContextAccessor CreateAccessor(int userId = 1, string username = "testuser")
        {
            var mock = new Mock<IHttpContextAccessor>();
            var context = new DefaultHttpContext();
            var identity = new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, username),
                new Claim("UserId", userId.ToString()),
                new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            }, "mock");
            context.User = new ClaimsPrincipal(identity);
            mock.Setup(h => h.HttpContext).Returns(context);
            return mock.Object;
        }
    }
}
