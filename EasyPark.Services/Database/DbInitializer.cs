using EasyPark.Services.Helpers;
using Microsoft.EntityFrameworkCore;

namespace EasyPark.Services.Database
{
    public static class DbInitializer
    {
        public static void Seed(EasyParkDbContext context)
        {
            if (context.Roles.Any())
            {
                return;
            }

            var adminRole = new Role { Name = "Admin" };
            var userRole = new Role { Name = "User" };

            context.Roles.AddRange(adminRole, userRole);
            context.SaveChanges();

            var adminSalt = HashGenerator.GenerateSalt();
            var adminUser = new User
            {
                FirstName = "Admin",
                LastName = "User",
                Username = "desktop",
                Email = "admin@easypark.com",
                Phone = "123456789",
                BirthDate = new DateOnly(1990, 1, 1),
                PasswordHash = HashGenerator.GenerateHash(adminSalt, "test"),
                PasswordSalt = adminSalt,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            context.Users.Add(adminUser);
            context.SaveChanges();

            context.UserRoles.Add(new UserRole
            {
                UserId = adminUser.Id,
                RoleId = adminRole.Id
            });

            var userSalt = HashGenerator.GenerateSalt();
            var regularUser = new User
            {
                FirstName = "Mobile",
                LastName = "User",
                Username = "mobile",
                Email = "user@easypark.com",
                Phone = "987654321",
                BirthDate = new DateOnly(1995, 5, 15),
                PasswordHash = HashGenerator.GenerateHash(userSalt, "test"),
                PasswordSalt = userSalt,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            context.Users.Add(regularUser);
            context.SaveChanges();

            context.UserRoles.Add(new UserRole
            {
                UserId = regularUser.Id,
                RoleId = userRole.Id
            });

            context.SaveChanges();
        }
    }
}
