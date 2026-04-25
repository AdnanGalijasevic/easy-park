using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;

namespace EasyPark.Services.Services
{
    public class UserService : BaseCRUDService<Model.Models.User, UserSearchObject, Database.User, UserInsertRequest, UserUpdateRequest>, IUserService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IRabbitMQService _rabbitMQService;

        public UserService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor, IRabbitMQService rabbitMQService) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
            _rabbitMQService = rabbitMQService;
        }

        public override IQueryable<Database.User> AddFilter(UserSearchObject search, IQueryable<Database.User> query)
        {
            ArgumentNullException.ThrowIfNull(search);
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery
                .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role);

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                filteredQuery = filteredQuery.Where(x =>
                    x.FirstName.Contains(search.FTS) ||
                    x.LastName.Contains(search.FTS) ||
                    x.Username.Contains(search.FTS) ||
                    x.Email.Contains(search.FTS));
            }

            filteredQuery = filteredQuery.Where(x =>
                !x.UserRoles.Any(ur => ur.Role != null && ur.Role.Name == "Admin")
            );

            if (search.FromDate.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.BirthDate >= search.FromDate.Value);
            }

            if (search.ToDate.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.BirthDate <= search.ToDate.Value);
            }

            if (search.IsActive.HasValue)
            {
                filteredQuery = filteredQuery.Where(x => x.IsActive == search.IsActive.Value);
            }

            filteredQuery = filteredQuery.OrderByDescending(p => p.CreatedAt);

            return filteredQuery;
        }

        public override void BeforeInsert(UserInsertRequest request, Database.User entity)
        {
            if (Context.Users.Any(u => u.Username == request.Username))
            {
                throw new UserException("Username taken", HttpStatusCode.BadRequest);
            }

            if (Context.Users.Any(u => u.Email == request.Email))
            {
                throw new UserException("Email already used", HttpStatusCode.BadRequest);
            }

            var pwValidationResult = ValidationHelpers.CheckPasswordStrength(request.Password);
            if (!string.IsNullOrEmpty(pwValidationResult))
            {
                throw new UserException("Invalid password", HttpStatusCode.BadRequest);
            }

            if (!string.IsNullOrEmpty(request.Phone))
            {
                var phoneValidationResult = ValidationHelpers.CheckPhoneNumber(request.Phone);
                if (!string.IsNullOrEmpty(phoneValidationResult))
                {
                    throw new UserException("Invalid phone number", HttpStatusCode.BadRequest);
                }
            }

            if (request.Password != request.PasswordConfirm)
            {
                throw new UserException("Password and confirm password are not matching", HttpStatusCode.BadRequest);
            }

            entity.PasswordSalt = HashGenerator.GenerateSalt();
            entity.PasswordHash = HashGenerator.GenerateHash(entity.PasswordSalt, request.Password);
            entity.IsActive = true;

            var defaultRole = Context.Roles.FirstOrDefault(r => r.Name == "User");
            if (defaultRole == null)
            {
                // System configuration error — not a user error
                throw new Exception("Default 'User' role not found in database. Check DB seed.");
            }

            entity.UserRoles = new List<Database.UserRole>
            {
                new Database.UserRole
                {
                    RoleId = defaultRole.Id
                }
            };
        }

        public override Model.Models.User GetById(int id)
        {
            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) && CurrentUserHelper.GetRequiredUserId(_httpContextAccessor) != id)
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            return base.GetById(id);
        }

        public override void Delete(int id)
        {
            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor))
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            base.Delete(id);
        }

        public override void BeforeUpdate(UserUpdateRequest request, Database.User entity)
        {
            if (entity == null)
                throw new UserException("User not found.", HttpStatusCode.NotFound);

            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) && CurrentUserHelper.GetRequiredUserId(_httpContextAccessor) != entity.Id)
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);

            if (!entity.IsActive)
                throw new UserException("Cannot update data of an inactive user.", HttpStatusCode.Forbidden);

            if (!string.IsNullOrWhiteSpace(request.Phone))
            {
                var phoneError = ValidationHelpers.CheckPhoneNumber(request.Phone);
                if (!string.IsNullOrEmpty(phoneError))
                    throw new UserException("Invalid phone number", HttpStatusCode.BadRequest);
            }

            if (!string.IsNullOrWhiteSpace(request.NewPassword))
            {
                if (string.IsNullOrWhiteSpace(request.CurrentPassword))
                    throw new UserException("Current password is required to change your password.", HttpStatusCode.BadRequest);

                var isCurrentPasswordValid = HashGenerator.Verify(request.CurrentPassword, entity.PasswordHash, entity.PasswordSalt);

                if (!isCurrentPasswordValid)
                    throw new UserException("Current password is incorrect.", HttpStatusCode.Unauthorized);

                var pwError = ValidationHelpers.CheckPasswordStrength(request.NewPassword);
                if (!string.IsNullOrEmpty(pwError))
                    throw new UserException("Invalid password", HttpStatusCode.BadRequest);

                if (request.NewPassword != request.NewPasswordConfirm)
                    throw new UserException("New password and confirmation do not match.", HttpStatusCode.BadRequest);

                entity.PasswordSalt = HashGenerator.GenerateSalt();
                entity.PasswordHash = HashGenerator.GenerateHash(entity.PasswordSalt, request.NewPassword);
            }
        }

        public async Task<List<Model.Models.Role>> GetUserRolesAsync(int id)
        {
            var roles = await Context.UserRoles
                .Where(ur => ur.UserId == id)
                .Select(ur => ur.Role)
                .ToListAsync();

            return Mapper.Map<List<Model.Models.Role>>(roles);
        }

        public Model.Models.User Login(string username, string password)
        {
            if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            {
                throw new UserException("Username and password are required", HttpStatusCode.BadRequest);
            }

            var entity = Context.Users
                .Include(u => u.UserRoles)
                .ThenInclude(r => r.Role)
                .FirstOrDefault(x => x.Username == username);

            if (entity == null)
            {
                throw new UserException("User not found", HttpStatusCode.Unauthorized);
            }

            if (!entity.IsActive)
            {
                throw new UserException("Your account has been deactivated. Please contact the administrator for help.", HttpStatusCode.Forbidden);
            }

            var isPasswordValid = HashGenerator.Verify(password, entity.PasswordHash, entity.PasswordSalt);
            if (!isPasswordValid)
            {
                throw new UserException("Invalid username or password", HttpStatusCode.Unauthorized);
            }

            // Migrate legacy SHA1 hash to BCrypt on successful login.
            if (!entity.PasswordHash.StartsWith("$2", StringComparison.Ordinal))
            {
                entity.PasswordSalt = HashGenerator.GenerateSalt();
                entity.PasswordHash = HashGenerator.GenerateHash(entity.PasswordSalt, password);
                Context.SaveChanges();
            }

            return Mapper.Map<Model.Models.User>(entity);
        }

        public Model.Models.User GetForAuth(int id)
        {
            var entity = Context.Users
                .Include(u => u.UserRoles)
                .ThenInclude(r => r.Role)
                .FirstOrDefault(x => x.Id == id);

            if (entity == null)
                throw new UserException("User not found", HttpStatusCode.Unauthorized);

            if (!entity.IsActive)
                throw new UserException("Your account has been deactivated. Please contact the administrator for help.", HttpStatusCode.Forbidden);

            return Mapper.Map<Model.Models.User>(entity);
        }

        public Model.Models.User ToggleActiveStatus(int userId, UserToggleActiveRequest request)
        {
            var user = Context.Users
                .Include(u => u.UserRoles)
                    .ThenInclude(ur => ur.Role)
                .FirstOrDefault(u => u.Id == userId);

            if (user == null)
                throw new UserException("User not found.", HttpStatusCode.NotFound);

            bool isAdmin = user.UserRoles.Any(ur => ur.Role.Name == "Admin");

            if (!request.IsActive && isAdmin)
                throw new UserException("Cannot deactivate a user with the Admin role.", HttpStatusCode.Forbidden);

            user.IsActive = request.IsActive;
            Context.SaveChanges();

            return Mapper.Map<Model.Models.User>(user);
        }

        public void ForgotPassword(string emailOrUsername)
        {
            if (string.IsNullOrWhiteSpace(emailOrUsername))
                throw new UserException("Email or username is required.", HttpStatusCode.BadRequest);

            var entity = Context.Users
                .FirstOrDefault(u => u.Email == emailOrUsername || u.Username == emailOrUsername);

            // Always return success — never reveal whether account exists (security).
            if (entity == null || !entity.IsActive) return;

            var token = Guid.NewGuid().ToString("N");
            entity.PasswordResetToken = token;
            entity.PasswordResetTokenExpiry = DateTime.UtcNow.AddHours(1);
            Context.SaveChanges();

            _rabbitMQService.PublishMessage("easypark_password_reset", new EasyPark.Model.Messages.PasswordResetRequested
            {
                Email = entity.Email,
                Name = $"{entity.FirstName} {entity.LastName}".Trim(),
                ResetToken = token
            });
        }

        public void ResetPassword(string token, string newPassword, string confirmPassword)
        {
            if (string.IsNullOrWhiteSpace(token))
                throw new UserException("Reset token is required.", HttpStatusCode.BadRequest);

            if (newPassword != confirmPassword)
                throw new UserException("Passwords do not match.", HttpStatusCode.BadRequest);

            var pwError = ValidationHelpers.CheckPasswordStrength(newPassword);
            if (!string.IsNullOrEmpty(pwError))
                throw new UserException("Invalid password: " + pwError, HttpStatusCode.BadRequest);

            var entity = Context.Users
                .FirstOrDefault(u => u.PasswordResetToken == token);

            if (entity == null || entity.PasswordResetTokenExpiry == null || entity.PasswordResetTokenExpiry < DateTime.UtcNow)
                throw new UserException("Reset token is invalid or has expired.", HttpStatusCode.BadRequest);

            entity.PasswordSalt = HashGenerator.GenerateSalt();
            entity.PasswordHash = HashGenerator.GenerateHash(entity.PasswordSalt, newPassword);
            entity.PasswordResetToken = null;
            entity.PasswordResetTokenExpiry = null;
            Context.SaveChanges();
        }
    }
}
