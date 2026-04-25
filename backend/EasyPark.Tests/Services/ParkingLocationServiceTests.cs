using System;
using System.Collections.Generic;
using System.Linq;
using EasyPark.Model.Models;
using EasyPark.Services.Database;
using EasyPark.Services.Services;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace EasyPark.Tests.Services
{
    public class ParkingLocationServiceTests
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
            mockMapper.Setup(m => m.Map<EasyPark.Model.Models.ParkingLocation>(It.IsAny<EasyPark.Services.Database.ParkingLocation>()))
                .Returns((EasyPark.Services.Database.ParkingLocation source) => new EasyPark.Model.Models.ParkingLocation { Id = source.Id });
            return mockMapper.Object;
        }

        [Fact]
        public void GetRecommendationScores_ShouldReturnEmpty_WhenUserHasNoReservations()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ParkingLocationService(context, mapper, httpContextAccessor);

            // Act
            var scores = service.GetRecommendationScores(1);

            // Assert
            Assert.Empty(scores);
        }

        [Fact]
        public void GetRecommendationScores_ShouldReturnScores_WhenUserHasCompletedReservations()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ParkingLocationService(context, mapper, httpContextAccessor);

            // Setup Data
            var user = new EasyPark.Services.Database.User 
            { 
                Id = 1, Username = "user1", Email = "u1@e.com", FirstName = "F", LastName = "L", 
                PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1), CreatedAt = DateTime.Now 
            };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1,
                Name = "Test Location",
                Address = "Address",
                CityId = 1,
                IsActive = true,
                PricePerHour = 2.0m,
                HasVideoSurveillance = true,
                CreatedAt = DateTime.Now,
                CreatedBy = 1,
                CreatedByUser = user
            };
            context.ParkingLocations.Add(location);

            var spot = new EasyPark.Services.Database.ParkingSpot
            {
                Id = 1,
                SpotNumber = "A1",
                SpotType = "Regular",
                ParkingLocationId = 1,
                IsActive = true,
                CreatedAt = DateTime.Now,
                ParkingLocation = location
            };
            context.ParkingSpots.Add(spot);

            var reservation = new EasyPark.Services.Database.Reservation
            {
                Id = 1,
                UserId = 1,
                ParkingSpotId = 1,
                StartTime = DateTime.Now.AddDays(-1),
                EndTime = DateTime.Now.AddDays(-1).AddHours(2),
                Status = "Completed",
                TotalPrice = 4.0m,
                CreatedAt = DateTime.Now.AddDays(-1),
                User = user,
                ParkingSpot = spot
            };
            context.Reservations.Add(reservation);
            context.SaveChanges();

            // Act
            var scores = service.GetRecommendationScores(1);

            // Assert
            Assert.NotEmpty(scores);
            Assert.Contains(scores, s => s.Id == 1);
            var resultLoc = scores.First(s => s.Id == 1);
            Assert.True(resultLoc.CbfScore > 0);
            Assert.NotNull(resultLoc.CbfExplanation);
        }
    }
}
