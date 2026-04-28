using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.API.Security;
using EasyPark.Services.Interfaces;

namespace EasyPark.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserController : BaseCRUDController<User, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        protected new IUserService _service;
        private readonly ITokenSecurityService _tokenSecurityService;

        public UserController(IUserService service, ITokenSecurityService tokenSecurityService) : base(service)
        {
            _service = service;
            _tokenSecurityService = tokenSecurityService;
        }

        [AllowAnonymous]
        [HttpPost]
        public override User Insert(UserInsertRequest request)
        {
            return base.Insert(request);
        }

        [Authorize(Roles = "Admin")]
        [HttpGet]
        public override PagedResult<User> GetList([FromQuery] UserSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [Authorize(Roles = "Admin")]
        [HttpDelete("{id}")]
        public override IActionResult Delete(int id)
        {
            return base.Delete(id);
        }

        [HttpPost("login")]
        [AllowAnonymous]
        public IActionResult Login([FromBody] LoginRequest request)
        {
            var clientType = Request.Headers["X-Client-Type"].ToString();
            var user = _service.Login(request.username, request.password, clientType);

            var authResponse = _tokenSecurityService.CreateAuthResponse(user);
            return Ok(authResponse);
        }

        [AllowAnonymous]
        [HttpPost("refresh")]
        public IActionResult Refresh([FromBody] TokenRefreshRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.RefreshToken))
            {
                return BadRequest(new { message = "Refresh token is required." });
            }

            if (!_tokenSecurityService.TryRotateRefreshToken(request.RefreshToken, out var userId))
            {
                return Unauthorized(new { message = "Invalid or expired refresh token." });
            }

            var user = _service.GetForAuth(userId);
            return Ok(_tokenSecurityService.CreateAuthResponse(user));
        }

        [Authorize]
        [HttpPost("logout")]
        public IActionResult Logout([FromBody] LogoutRequest? request)
        {
            var authHeader = Request.Headers.Authorization.ToString();
            if (authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                _tokenSecurityService.RevokeJwt(authHeader["Bearer ".Length..].Trim());
            }

            if (!string.IsNullOrWhiteSpace(request?.RefreshToken))
            {
                _tokenSecurityService.RevokeRefreshToken(request.RefreshToken);
            }

            return Ok(new { message = "Logged out." });
        }

        [Authorize(Roles = "Admin")]
        [HttpPatch("{id}/status")]
        public IActionResult ToggleUserStatus(int id, [FromBody] UserToggleActiveRequest request)
        {
            var user = _service.ToggleActiveStatus(id, request);
            return Ok(user);
        }

        [AllowAnonymous]
        [HttpPost("forgot-password")]
        public IActionResult ForgotPassword([FromBody] ForgotPasswordRequest request)
        {
            _service.ForgotPassword(request.EmailOrUsername);
            return Ok(new { message = "If an account with that email or username exists, a password reset link has been sent." });
        }

        [AllowAnonymous]
        [HttpPost("reset-password")]
        public IActionResult ResetPassword([FromBody] ResetPasswordRequest request)
        {
            _service.ResetPassword(request.Token, request.NewPassword, request.ConfirmPassword);
            return Ok(new { message = "Password reset successfully." });
        }
    }
}
