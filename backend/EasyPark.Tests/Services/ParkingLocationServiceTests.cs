using System;
using System.Collections.Generic;
using System.Linq;
using EasyPark.Model;
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
        public void GetRecommendationScores_ShouldReturnFallbackRated_WhenUserHasNoReservations()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ParkingLocationService(context, mapper, httpContextAccessor);

            // DB stores UTC in production; DateTime.Now is test-only fixture value.
            var city = new EasyPark.Services.Database.City { Id = 1, Name = "Mostar" };
            context.Cities.Add(city);
            var user = new EasyPark.Services.Database.User
            {
                Id = 1, Username = "user1", Email = "u1@e.com", FirstName = "F", LastName = "L",
                PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1), CreatedAt = DateTime.Now
            };
            context.Users.Add(user);
            context.ParkingLocations.Add(new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1, Name = "Top Rated", Address = "Addr", CityId = 1, IsActive = true,
                PricePerHour = 2.0m, AverageRating = 4.5m, CreatedAt = DateTime.Now, CreatedBy = 1
            });
            context.SaveChanges();

            var scores = service.GetRecommendationScores(1);

            Assert.NotEmpty(scores);
            Assert.True(scores.Count <= 3);
            Assert.All(scores, s => Assert.True(s.CbfScore > 0));
            Assert.All(scores, s => Assert.Contains("rated", s.CbfExplanation, StringComparison.OrdinalIgnoreCase));
        }

        [Fact]
        public void GetRecommendationScores_ShouldReturnScores_WhenUserHasCompletedReservations()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ParkingLocationService(context, mapper, httpContextAccessor);

            var user = new EasyPark.Services.Database.User 
            { 
                Id = 1, Username = "user1", Email = "u1@e.com", FirstName = "F", LastName = "L", 
                PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1), CreatedAt = DateTime.Now 
            };
            context.Users.Add(user);
            var city = new EasyPark.Services.Database.City
            {
                Id = 1,
                Name = "Mostar"
            };
            context.Cities.Add(city);

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
                City = city,
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

            var scores = service.GetRecommendationScores(1);

            Assert.NotEmpty(scores);
            Assert.Contains(scores, s => s.Id == 1);
            var resultLoc = scores.First(s => s.Id == 1);
            Assert.True(resultLoc.CbfScore > 0);
            Assert.NotNull(resultLoc.CbfExplanation);
        }

        [Fact]
        public void Delete_ShouldRemoveLocationSpotsReservationsAndRefundUsers()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ParkingLocationService(context, mapper, httpContextAccessor);

            var city = new EasyPark.Services.Database.City { Id = 1, Name = "Mostar" };
            context.Cities.Add(city);

            var user = new EasyPark.Services.Database.User
            {
                Id = 1,
                Username = "u",
                Email = "u@e.com",
                FirstName = "F",
                LastName = "L",
                PasswordHash = "h",
                PasswordSalt = "s",
                BirthDate = new DateOnly(1990, 1, 1),
                Coins = 10m,
                CreatedAt = DateTime.Now
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
                CreatedAt = DateTime.Now,
                CreatedBy = 1
            };
            context.ParkingLocations.Add(location);

            context.ParkingSpots.Add(new EasyPark.Services.Database.ParkingSpot
            {
                Id = 1,
                ParkingLocationId = 1,
                SpotNumber = "A1",
                SpotType = "Regular",
                IsActive = true,
                CreatedAt = DateTime.Now
            });

            context.Reservations.Add(new EasyPark.Services.Database.Reservation
            {
                Id = 1,
                UserId = 1,
                ParkingSpotId = 1,
                StartTime = DateTime.UtcNow.AddHours(1),
                EndTime = DateTime.UtcNow.AddHours(2),
                Status = "Pending",
                TotalPrice = 5m,
                CreatedAt = DateTime.UtcNow
            });

            context.SaveChanges();

            service.Delete(1);

            Assert.Null(context.ParkingLocations.Find(1));
            Assert.False(context.ParkingSpots.Any(s => s.ParkingLocationId == 1));
            Assert.False(context.Reservations.Any(r => r.ParkingSpotId == 1));

            var updatedUser = context.Users.Find(1);
            Assert.NotNull(updatedUser);
            Assert.Equal(15m, updatedUser!.Coins);
            Assert.True(context.Transactions.Any(t => t.Status == "Refunded" && t.UserId == 1 && t.Amount == 5m));
        }

        [Fact]
        public void Delete_ShouldRemoveLocation_WhenNoRelatedData()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ParkingLocationService(context, mapper, httpContextAccessor);

            var city = new EasyPark.Services.Database.City { Id = 1, Name = "Mostar" };
            context.Cities.Add(city);

            var location = new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1,
                Name = "Delete Me",
                Address = "Address",
                CityId = 1,
                IsActive = true,
                PricePerHour = 2.0m,
                CreatedAt = DateTime.Now,
                CreatedBy = 1
            };

            context.ParkingLocations.Add(location);
            context.SaveChanges();

            service.Delete(1);

            Assert.Null(context.ParkingLocations.Find(1));
        }

        [Fact]
        public void Delete_ShouldRemoveLocationAndRelatedReviewsAndBookmarks()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ParkingLocationService(context, mapper, httpContextAccessor);

            var city = new EasyPark.Services.Database.City { Id = 1, Name = "Mostar" };
            context.Cities.Add(city);

            var user = new EasyPark.Services.Database.User
            {
                Id = 1,
                Username = "user1",
                Email = "u1@e.com",
                FirstName = "F",
                LastName = "L",
                PasswordHash = "h",
                PasswordSalt = "s",
                BirthDate = new DateOnly(1990, 1, 1),
                CreatedAt = DateTime.Now
            };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1,
                Name = "Delete Me",
                Address = "Address",
                CityId = 1,
                IsActive = true,
                PricePerHour = 2.0m,
                CreatedAt = DateTime.Now,
                CreatedBy = 1
            };
            context.ParkingLocations.Add(location);

            context.Reviews.Add(new EasyPark.Services.Database.Review
            {
                Id = 1,
                UserId = 1,
                ParkingLocationId = 1,
                Rating = 5,
                Comment = "Great",
                CreatedAt = DateTime.Now
            });

            context.Bookmarks.Add(new EasyPark.Services.Database.Bookmark
            {
                Id = 1,
                UserId = 1,
                ParkingLocationId = 1,
                CreatedAt = DateTime.Now
            });

            context.SaveChanges();

            service.Delete(1);

            Assert.Null(context.ParkingLocations.Find(1));
            Assert.False(context.Reviews.Any(r => r.ParkingLocationId == 1));
            Assert.False(context.Bookmarks.Any(b => b.ParkingLocationId == 1));
        }
    }
}
