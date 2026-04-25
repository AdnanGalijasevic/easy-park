using System;
using System.Collections.Generic;
using System.Linq;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Services.Database;
using EasyPark.Services.Services;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;
using EasyPark.Model;

namespace EasyPark.Tests.Services
{
    public class BookmarkServiceTests
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
            return mockMapper.Object;
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenParkingLocationNotFound()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new BookmarkService(context, mapper, httpContextAccessor);

            var request = new BookmarkInsertRequest { ParkingLocationId = 999 };
            var entity = new EasyPark.Services.Database.Bookmark();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("Parking location not found", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenDuplicateBookmark()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new BookmarkService(context, mapper, httpContextAccessor);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "testuser", Email = "t@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1) };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, CreatedByUser = user };
            context.ParkingLocations.Add(location);

            var existingBookmark = new EasyPark.Services.Database.Bookmark { Id = 1, UserId = 1, ParkingLocationId = 1 };
            context.Bookmarks.Add(existingBookmark);
            context.SaveChanges();

            var request = new BookmarkInsertRequest { ParkingLocationId = 1 };
            var entity = new EasyPark.Services.Database.Bookmark();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("You have already bookmarked this parking location", exception.Message);
        }
    }
}
