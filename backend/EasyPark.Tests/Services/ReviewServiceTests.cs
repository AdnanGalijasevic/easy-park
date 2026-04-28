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
    public class ReviewServiceTests
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
            mockMapper.Setup(m => m.Map<EasyPark.Model.Models.Review>(It.IsAny<EasyPark.Services.Database.Review>()))
                .Returns((EasyPark.Services.Database.Review source) => new EasyPark.Model.Models.Review
                {
                    Id = source.Id,
                    UserId = source.UserId,
                    ParkingLocationId = source.ParkingLocationId,
                    Rating = source.Rating,
                    Comment = source.Comment
                });
            return mockMapper.Object;
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenRatingIsInvalid()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReviewService(context, mapper, httpContextAccessor);

            var request = new ReviewInsertRequest { Rating = 6 };
            var entity = new EasyPark.Services.Database.Review();

            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("Rating must be between 1 and 5", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenDuplicateReview()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReviewService(context, mapper, httpContextAccessor);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "testuser", Email = "t@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1) };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, CreatedByUser = user };
            context.ParkingLocations.Add(location);

            var existingReview = new EasyPark.Services.Database.Review { Id = 1, UserId = 1, ParkingLocationId = 1, Rating = 5 };
            context.Reviews.Add(existingReview);
            context.SaveChanges();

            var request = new ReviewInsertRequest { ParkingLocationId = 1, Rating = 4 };
            var entity = new EasyPark.Services.Database.Review();

            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("You have already reviewed this parking location", exception.Message);
        }
    }
}
