using System;
using System.Linq;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Services.Database;
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Services;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace EasyPark.Tests.Services
{
    public class UserServiceTests
    {
        private EasyParkDbContext GetInMemoryContext()
        {
            var options = new DbContextOptionsBuilder<EasyParkDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            return new EasyParkDbContext(options);
        }

        private IMapper GetMockMapper()
        {
            var mockMapper = new Mock<IMapper>();
            mockMapper.Setup(m => m.Map<EasyPark.Model.Models.User>(It.IsAny<EasyPark.Services.Database.User>()))
                .Returns((EasyPark.Services.Database.User source) => new EasyPark.Model.Models.User
                {
                    Id = source.Id,
                    FirstName = source.FirstName,
                    LastName = source.LastName,
                    Username = source.Username,
                    Email = source.Email,
                    IsActive = source.IsActive
                });

            return mockMapper.Object;
        }

        [Fact]
        public void ToggleActiveStatus_ShouldDeactivateUser_WhenCalledWithFalse()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new UserService(context, mapper, TestClaimsHelper.CreateAccessor(), new Mock<IRabbitMQService>().Object);

            var userRoleObject = new EasyPark.Services.Database.Role { Id = 1, Name = "User" };
            context.Roles.Add(userRoleObject);
            
            // DB stores UTC in production; DateTime.Now is test-only fixture value.
            var user = new EasyPark.Services.Database.User
            {
                Id = 1,
                FirstName = "Test",
                LastName = "User",
                Username = "testuser",
                Email = "test@example.com",
                IsActive = true,
                PasswordHash = "hash",
                PasswordSalt = "salt",
                BirthDate = new DateOnly(2000, 1, 1),
                CreatedAt = DateTime.Now
            };
            
            context.Users.Add(user);
            context.SaveChanges();
            
            var userRole = new EasyPark.Services.Database.UserRole
            {
                UserId = user.Id,
                RoleId = userRoleObject.Id
            };
            context.UserRoles.Add(userRole);
            context.SaveChanges();

            var toggleRequest = new UserToggleActiveRequest { IsActive = false };

            var result = service.ToggleActiveStatus(1, toggleRequest);

            var updatedUser = context.Users.Find(1);
            Assert.NotNull(updatedUser);
            Assert.False(updatedUser.IsActive);
            Assert.False(result.IsActive);
        }
        
        [Fact]
        public void ToggleActiveStatus_ShouldThrowException_WhenUserIsAdmin()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new UserService(context, mapper, TestClaimsHelper.CreateAccessor(), new Mock<IRabbitMQService>().Object);

            var adminRole = new EasyPark.Services.Database.Role { Id = 1, Name = "Admin" };
            context.Roles.Add(adminRole);
            
            var adminUser = new EasyPark.Services.Database.User
            {
                Id = 2,
                FirstName = "Admin",
                LastName = "User",
                Username = "adminuser",
                Email = "admin@example.com",
                IsActive = true,
                PasswordHash = "hash",
                PasswordSalt = "salt",
                BirthDate = new DateOnly(1990, 5, 5),
                CreatedAt = DateTime.Now
            };
            
            context.Users.Add(adminUser);
            context.SaveChanges();

            var userRole = new EasyPark.Services.Database.UserRole
            {
                UserId = adminUser.Id,
                RoleId = adminRole.Id
            };
            context.UserRoles.Add(userRole);
            context.SaveChanges();

            var toggleRequest = new UserToggleActiveRequest { IsActive = false };

            var exception = Assert.Throws<UserException>(() => service.ToggleActiveStatus(2, toggleRequest));
            Assert.Equal("Cannot deactivate a user with the Admin role.", exception.Message);
        }
    }
}
