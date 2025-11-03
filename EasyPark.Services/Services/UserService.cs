using MapsterMapper;
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
        public UserService(EasyParkDbContext context, IMapper mapper) : base(context, mapper)
        {
        }

        public override IQueryable<Database.User> AddFilter(UserSearchObject search, IQueryable<Database.User> query)
        {
            var filteredQuery = base.AddFilter(search, query);

             filteredQuery = filteredQuery
        .Include(u => u.UserRoles)
        .ThenInclude(ur => ur.Role);

            if (!string.IsNullOrWhiteSpace(search?.FTS))
            {
                filteredQuery = filteredQuery.Where(x =>
                    x.FirstName.Contains(search.FTS) ||
                    x.LastName.Contains(search.FTS) ||
                    x.Username.Contains(search.FTS) ||
                    x.Email.Contains(search.FTS));
            }

            filteredQuery = filteredQuery.Where(x =>
                !x.UserRoles.Any(ur => ur.Role.Name == "Admin")
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
                throw new UserException("Default 'User' role not found in the database.", HttpStatusCode.InternalServerError);
            }

            entity.UserRoles = new List<Database.UserRole>
            {
                new Database.UserRole
                {
                    RoleId = defaultRole.Id
                }
            };
        }

        public override void BeforeUpdate(UserUpdateRequest request, Database.User entity)
        {
            base.BeforeUpdate(request, entity);

            if (entity == null)
                throw new UserException("User entity not found.", HttpStatusCode.NotFound);

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

                var isCurrentPasswordValid = entity.PasswordHash ==
                    HashGenerator.GenerateHash(entity.PasswordSalt, request.CurrentPassword);

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

            if (!string.IsNullOrWhiteSpace(request.FirstName))
                entity.FirstName = request.FirstName;

            if (!string.IsNullOrWhiteSpace(request.LastName))
                entity.LastName = request.LastName;

            if (!string.IsNullOrWhiteSpace(request.Username))
                entity.Username = request.Username;

            if (!string.IsNullOrWhiteSpace(request.Email))
                entity.Email = request.Email;

            if (!string.IsNullOrWhiteSpace(request.Phone))
                entity.Phone = request.Phone;

            if (request.BirthDate.HasValue)
                entity.BirthDate = request.BirthDate.Value;
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

            var hash = HashGenerator.GenerateHash(entity.PasswordSalt, password);

            if (hash != entity.PasswordHash)
            {
                throw new UserException("Invalid username or password", HttpStatusCode.Unauthorized);
            }

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
    }
}
