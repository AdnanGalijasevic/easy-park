using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Services;

namespace backend.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserController : BaseCRUDController<User, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        protected new IUserService _service;
        public UserController(IUserService service) : base(service)
        {
            _service = service;
        }

        [AllowAnonymous]
        public override User Insert(UserInsertRequest request)
        {
            return base.Insert(request);
        }

        [HttpPost("login")]
        [AllowAnonymous]
        public IActionResult Login([FromBody] LoginRequest request)
        {
            var user = _service.Login(request.username, request.password);

            var clientTypeRaw = Request.Headers["X-Client-Type"].ToString();
            var clientType = clientTypeRaw?.Trim().ToLower();

            if (string.IsNullOrEmpty(clientType) || (clientType != "desktop" && clientType != "mobile"))
            {
                return BadRequest(new { message = "Invalid or missing 'X-Client-Type' header. Must be 'desktop' or 'mobile'." });
            }

            if (clientType == "desktop" && !user.Roles.Contains("Admin"))
            {
                return Unauthorized(new { message = "Only admins can log in from the desktop app." });
            }

            if (clientType == "mobile" && user.Roles.Contains("Admin"))
            {
                return Unauthorized(new { message = "Admins cannot log in from the mobile app." });
            }

            return Ok(user);
        }

        [Authorize(Roles = "Admin")]
        [HttpPatch("{id}/status")]
        public IActionResult ToggleUserStatus(int id, [FromBody] UserToggleActiveRequest request)
        {
            var user = _service.ToggleActiveStatus(id, request);
            return Ok(user);
        }
    }
}
