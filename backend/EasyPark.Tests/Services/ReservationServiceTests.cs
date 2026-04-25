using System;
using System.Collections.Generic;
using System.Linq;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Services;
using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;
using EasyPark.Model;
using System.Security.Claims;

namespace EasyPark.Tests.Services
{
    public class ReservationServiceTests
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
            mockMapper.Setup(m => m.Map<EasyPark.Model.Models.Reservation>(It.IsAny<EasyPark.Services.Database.Reservation>()))
                .Returns((EasyPark.Services.Database.Reservation source) => new EasyPark.Model.Models.Reservation
                {
                    Id = source.Id,
                    UserId = source.UserId,
                    ParkingSpotId = source.ParkingSpotId,
                    StartTime = source.StartTime,
                    EndTime = source.EndTime,
                    Status = source.Status,
                    TotalPrice = source.TotalPrice
                });
            return mockMapper.Object;
        }

        private IHttpContextAccessor CreateAdminAccessor(int userId = 1, string username = "admin")
        {
            var mock = new Mock<IHttpContextAccessor>();
            var context = new DefaultHttpContext();
            var identity = new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, username),
                new Claim("UserId", userId.ToString()),
                new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
                new Claim(ClaimTypes.Role, "Admin"),
            }, "mock");
            context.User = new ClaimsPrincipal(identity);
            mock.Setup(h => h.HttpContext).Returns(context);
            return mock.Object;
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenParkingSpotNotFound()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var historyService = new Mock<IReservationHistoryService>();
            var rabbitMQService = new Mock<IRabbitMQService>();
            var service = new ReservationService(context, mapper, httpContextAccessor, historyService.Object, rabbitMQService.Object);

            var startTime = DateTime.UtcNow.AddHours(1);
            var endTime = startTime.AddHours(1);
            var request = new ReservationInsertRequest
            {
                ParkingSpotId = 999,
                StartTime = startTime,
                EndTime = endTime,
            };
            var entity = new EasyPark.Services.Database.Reservation();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("Parking spot not found", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenEndTimeIsBeforeStartTime()
        {
            var context = GetInMemoryContext();
            var service = new ReservationService(
                context,
                GetMockMapper(),
                TestClaimsHelper.CreateAccessor(),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var now = DateTime.UtcNow.AddHours(2);
            var request = new ReservationInsertRequest
            {
                ParkingSpotId = 1,
                StartTime = now,
                EndTime = now
            };

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, new EasyPark.Services.Database.Reservation()));
            Assert.Equal("End time must be after start time", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenStartTimeIsInPast()
        {
            var context = GetInMemoryContext();
            var service = new ReservationService(
                context,
                GetMockMapper(),
                TestClaimsHelper.CreateAccessor(),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var request = new ReservationInsertRequest
            {
                ParkingSpotId = 1,
                StartTime = DateTime.UtcNow.AddMinutes(-1),
                EndTime = DateTime.UtcNow.AddHours(1)
            };

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, new EasyPark.Services.Database.Reservation()));
            Assert.Equal("Start time cannot be in the past", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldCalculatePriceAndSetStatus()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var historyService = new Mock<IReservationHistoryService>();
            var rabbitMQService = new Mock<IRabbitMQService>();
            var service = new ReservationService(context, mapper, httpContextAccessor, historyService.Object, rabbitMQService.Object);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "testuser", Email = "t@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1), Coins = 100m };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, PricePerHour = 10.0m, CreatedByUser = user };
            context.ParkingLocations.Add(location);

            var spot = new EasyPark.Services.Database.ParkingSpot { Id = 1, SpotNumber = "1", SpotType = "Regular", ParkingLocationId = 1, IsActive = true, ParkingLocation = location };
            context.ParkingSpots.Add(spot);
            context.SaveChanges();

            var startTime = DateTime.UtcNow.AddHours(1);
            var endTime = startTime.AddHours(2);
            var request = new ReservationInsertRequest 
            { 
                ParkingSpotId = 1, 
                StartTime = startTime, 
                EndTime = endTime,
                CancellationAllowed = true
            };
            var entity = new EasyPark.Services.Database.Reservation();

            // Act
            service.BeforeInsert(request, entity);

            // Assert
            Assert.Equal("Pending", entity.Status);
            Assert.Equal(20.0m, entity.TotalPrice); // 2 hours * 10.0m
            Assert.Equal(1, entity.UserId);
            Assert.NotNull(entity.QRCode);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenParkingSpotInactive()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReservationService(context, mapper, httpContextAccessor, new Mock<IReservationHistoryService>().Object, new Mock<IRabbitMQService>().Object);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "u", Email = "u@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1), Coins = 100m };
            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, PricePerHour = 5m, PriceRegular = 5m, CreatedBy = 1, CreatedByUser = user };
            var spot = new EasyPark.Services.Database.ParkingSpot { Id = 1, SpotNumber = "R1", SpotType = "Regular", ParkingLocationId = 1, IsActive = false, ParkingLocation = location };
            context.Users.Add(user);
            context.ParkingLocations.Add(location);
            context.ParkingSpots.Add(spot);
            context.SaveChanges();

            var now = DateTime.UtcNow.AddHours(1);
            var request = new ReservationInsertRequest { ParkingSpotId = 1, StartTime = now, EndTime = now.AddHours(1) };

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, new EasyPark.Services.Database.Reservation()));
            Assert.Equal("Parking spot is not active", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrowUnauthorized_WhenNoUserClaims()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var noClaimsAccessor = new Mock<IHttpContextAccessor>();
            noClaimsAccessor.Setup(a => a.HttpContext).Returns(new DefaultHttpContext());
            var historyService = new Mock<IReservationHistoryService>();
            var rabbitMQService = new Mock<IRabbitMQService>();
            var service = new ReservationService(
                context,
                mapper,
                noClaimsAccessor.Object,
                historyService.Object,
                rabbitMQService.Object);

            var user = new EasyPark.Services.Database.User
            {
                Id = 1,
                Username = "testuser",
                Email = "t@e.com",
                FirstName = "F",
                LastName = "L",
                PasswordHash = "h",
                PasswordSalt = "s",
                BirthDate = new DateOnly(1990, 1, 1),
                Coins = 100m
            };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1,
                Name = "L",
                Address = "A",
                CityId = 1,
                PricePerHour = 10m,
                PriceRegular = 10m,
                CreatedBy = 1,
                CreatedByUser = user
            };
            context.ParkingLocations.Add(location);

            context.ParkingSpots.Add(new EasyPark.Services.Database.ParkingSpot
            {
                Id = 1,
                SpotNumber = "R1",
                SpotType = "Regular",
                ParkingLocationId = 1,
                IsActive = true,
                ParkingLocation = location
            });
            context.SaveChanges();

            var startTime = DateTime.UtcNow.AddHours(1);
            var request = new ReservationInsertRequest
            {
                ParkingSpotId = 1,
                StartTime = startTime,
                EndTime = startTime.AddHours(1)
            };

            var entity = new EasyPark.Services.Database.Reservation();

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("User not authenticated", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenInsufficientCoins()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor(userId: 1);
            var historyService = new Mock<IReservationHistoryService>();
            var rabbitMQService = new Mock<IRabbitMQService>();
            var service = new ReservationService(context, mapper, httpContextAccessor, historyService.Object, rabbitMQService.Object);

            var user = new EasyPark.Services.Database.User
            {
                Id = 1,
                Username = "testuser",
                Email = "t@e.com",
                FirstName = "F",
                LastName = "L",
                PasswordHash = "h",
                PasswordSalt = "s",
                BirthDate = new DateOnly(1990, 1, 1),
                Coins = 1m
            };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1,
                Name = "L",
                Address = "A",
                CityId = 1,
                PricePerHour = 10m,
                PriceRegular = 10m,
                CreatedBy = 1,
                CreatedByUser = user
            };
            context.ParkingLocations.Add(location);

            var spot = new EasyPark.Services.Database.ParkingSpot
            {
                Id = 1,
                SpotNumber = "R1",
                SpotType = "Regular",
                ParkingLocationId = 1,
                IsActive = true,
                ParkingLocation = location
            };
            context.ParkingSpots.Add(spot);
            context.SaveChanges();

            var startTime = DateTime.UtcNow.AddHours(1);
            var request = new ReservationInsertRequest
            {
                ParkingSpotId = 1,
                StartTime = startTime,
                EndTime = startTime.AddHours(1)
            };
            var entity = new EasyPark.Services.Database.Reservation();

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Contains("Insufficient balance", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenSpotTypeMissingForAutoAssign()
        {
            var context = GetInMemoryContext();
            var service = new ReservationService(
                context,
                GetMockMapper(),
                TestClaimsHelper.CreateAccessor(),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var now = DateTime.UtcNow.AddHours(1);
            var request = new ReservationInsertRequest
            {
                ParkingLocationId = 1,
                SpotType = null,
                StartTime = now,
                EndTime = now.AddHours(1)
            };

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, new EasyPark.Services.Database.Reservation()));
            Assert.Contains("SpotType is required", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenParkingLocationMissingForAutoAssign()
        {
            var context = GetInMemoryContext();
            var service = new ReservationService(
                context,
                GetMockMapper(),
                TestClaimsHelper.CreateAccessor(),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var now = DateTime.UtcNow.AddHours(1);
            var request = new ReservationInsertRequest
            {
                SpotType = "Regular",
                StartTime = now,
                EndTime = now.AddHours(1)
            };

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, new EasyPark.Services.Database.Reservation()));
            Assert.Contains("ParkingLocationId is required", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenNoActiveSpotsForType()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new ReservationService(context, mapper, TestClaimsHelper.CreateAccessor(), new Mock<IReservationHistoryService>().Object, new Mock<IRabbitMQService>().Object);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "u", Email = "u@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1), Coins = 100m };
            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, PricePerHour = 5m, PriceRegular = 5m, CreatedBy = 1, CreatedByUser = user };
            context.Users.Add(user);
            context.ParkingLocations.Add(location);
            context.SaveChanges();

            var now = DateTime.UtcNow.AddHours(1);
            var request = new ReservationInsertRequest
            {
                ParkingLocationId = 1,
                SpotType = "Electric",
                StartTime = now,
                EndTime = now.AddHours(1)
            };

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, new EasyPark.Services.Database.Reservation()));
            Assert.Contains("No active Electric spots exist", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldAllow_WhenOnlyCancelledOrExpiredOverlapExists()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new ReservationService(context, mapper, TestClaimsHelper.CreateAccessor(userId: 1), new Mock<IReservationHistoryService>().Object, new Mock<IRabbitMQService>().Object);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "u", Email = "u@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1), Coins = 200m };
            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, PricePerHour = 5m, PriceRegular = 5m, CreatedBy = 1, CreatedByUser = user };
            var spot = new EasyPark.Services.Database.ParkingSpot { Id = 1, SpotNumber = "R1", SpotType = "Regular", ParkingLocationId = 1, IsActive = true, ParkingLocation = location };
            context.Users.Add(user);
            context.ParkingLocations.Add(location);
            context.ParkingSpots.Add(spot);
            var now = DateTime.UtcNow;
            context.Reservations.AddRange(
                new EasyPark.Services.Database.Reservation
                {
                    Id = 1,
                    UserId = 2,
                    ParkingSpotId = 1,
                    Status = "Cancelled",
                    StartTime = now.AddHours(2),
                    EndTime = now.AddHours(4),
                    TotalPrice = 10m,
                    CreatedAt = now
                },
                new EasyPark.Services.Database.Reservation
                {
                    Id = 2,
                    UserId = 2,
                    ParkingSpotId = 1,
                    Status = "Expired",
                    StartTime = now.AddHours(2),
                    EndTime = now.AddHours(4),
                    TotalPrice = 10m,
                    CreatedAt = now
                });
            context.SaveChanges();

            var request = new ReservationInsertRequest
            {
                ParkingSpotId = 1,
                StartTime = now.AddHours(3),
                EndTime = now.AddHours(5)
            };
            var entity = new EasyPark.Services.Database.Reservation();

            service.BeforeInsert(request, entity);

            Assert.Equal("Pending", entity.Status);
            Assert.Equal(1, entity.UserId);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenSpecificSpotOverlapsExistingActiveReservation()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor(userId: 1);
            var historyService = new Mock<IReservationHistoryService>();
            var rabbitMQService = new Mock<IRabbitMQService>();
            var service = new ReservationService(context, mapper, httpContextAccessor, historyService.Object, rabbitMQService.Object);

            var user = new EasyPark.Services.Database.User
            {
                Id = 1,
                Username = "testuser",
                Email = "t@e.com",
                FirstName = "F",
                LastName = "L",
                PasswordHash = "h",
                PasswordSalt = "s",
                BirthDate = new DateOnly(1990, 1, 1),
                Coins = 200m
            };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1,
                Name = "L",
                Address = "A",
                CityId = 1,
                PricePerHour = 5m,
                PriceRegular = 5m,
                CreatedBy = 1,
                CreatedByUser = user
            };
            context.ParkingLocations.Add(location);

            var spot = new EasyPark.Services.Database.ParkingSpot
            {
                Id = 1,
                SpotNumber = "R1",
                SpotType = "Regular",
                ParkingLocationId = 1,
                IsActive = true,
                ParkingLocation = location
            };
            context.ParkingSpots.Add(spot);

            var now = DateTime.UtcNow;
            context.Reservations.Add(new EasyPark.Services.Database.Reservation
            {
                Id = 99,
                UserId = 2,
                ParkingSpotId = 1,
                Status = "Active",
                StartTime = now.AddHours(2),
                EndTime = now.AddHours(4),
                TotalPrice = 10m,
                CreatedAt = now
            });
            context.SaveChanges();

            var request = new ReservationInsertRequest
            {
                ParkingSpotId = 1,
                StartTime = now.AddHours(3),
                EndTime = now.AddHours(5)
            };
            var entity = new EasyPark.Services.Database.Reservation();

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Contains("already reserved", ex.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrow_WhenAllSpotsOfTypeAreReserved()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor(userId: 1);
            var historyService = new Mock<IReservationHistoryService>();
            var rabbitMQService = new Mock<IRabbitMQService>();
            var service = new ReservationService(context, mapper, httpContextAccessor, historyService.Object, rabbitMQService.Object);

            var user = new EasyPark.Services.Database.User
            {
                Id = 1,
                Username = "testuser",
                Email = "t@e.com",
                FirstName = "F",
                LastName = "L",
                PasswordHash = "h",
                PasswordSalt = "s",
                BirthDate = new DateOnly(1990, 1, 1),
                Coins = 200m
            };
            context.Users.Add(user);

            var location = new EasyPark.Services.Database.ParkingLocation
            {
                Id = 1,
                Name = "L",
                Address = "A",
                CityId = 1,
                PricePerHour = 5m,
                PriceCovered = 7m,
                CreatedBy = 1,
                CreatedByUser = user
            };
            context.ParkingLocations.Add(location);

            context.ParkingSpots.AddRange(
                new EasyPark.Services.Database.ParkingSpot
                {
                    Id = 1,
                    SpotNumber = "C1",
                    SpotType = "Covered",
                    ParkingLocationId = 1,
                    IsActive = true,
                    ParkingLocation = location
                },
                new EasyPark.Services.Database.ParkingSpot
                {
                    Id = 2,
                    SpotNumber = "C2",
                    SpotType = "Covered",
                    ParkingLocationId = 1,
                    IsActive = true,
                    ParkingLocation = location
                });

            var now = DateTime.UtcNow;
            context.Reservations.AddRange(
                new EasyPark.Services.Database.Reservation
                {
                    Id = 100,
                    UserId = 2,
                    ParkingSpotId = 1,
                    Status = "Pending",
                    StartTime = now.AddHours(1),
                    EndTime = now.AddHours(3),
                    TotalPrice = 5m,
                    CreatedAt = now
                },
                new EasyPark.Services.Database.Reservation
                {
                    Id = 101,
                    UserId = 3,
                    ParkingSpotId = 2,
                    Status = "Active",
                    StartTime = now.AddHours(1),
                    EndTime = now.AddHours(3),
                    TotalPrice = 5m,
                    CreatedAt = now
                });
            context.SaveChanges();

            var request = new ReservationInsertRequest
            {
                ParkingLocationId = 1,
                SpotType = "Covered",
                StartTime = now.AddHours(1).AddMinutes(15),
                EndTime = now.AddHours(2)
            };
            var entity = new EasyPark.Services.Database.Reservation();

            var ex = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Contains("All Covered spots are reserved", ex.Message);
        }

        [Fact]
        public void BeforeUpdate_ShouldThrow_WhenInvalidStatusProvided()
        {
            var context = GetInMemoryContext();
            var service = new ReservationService(
                context,
                GetMockMapper(),
                TestClaimsHelper.CreateAccessor(userId: 1),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var entity = new EasyPark.Services.Database.Reservation
            {
                Id = 1,
                UserId = 1,
                ParkingSpotId = 1,
                Status = "Pending",
                StartTime = DateTime.UtcNow.AddHours(1),
                EndTime = DateTime.UtcNow.AddHours(2)
            };

            var request = new ReservationUpdateRequest { Status = "UnknownStatus" };
            var ex = Assert.Throws<UserException>(() => service.BeforeUpdate(request, entity));
            Assert.Contains("Invalid status", ex.Message);
        }

        [Fact]
        public void BeforeUpdate_ShouldThrowForbidden_WhenNonOwnerAndNonAdmin()
        {
            var context = GetInMemoryContext();
            var service = new ReservationService(
                context,
                GetMockMapper(),
                TestClaimsHelper.CreateAccessor(userId: 1),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var entity = new EasyPark.Services.Database.Reservation
            {
                Id = 1,
                UserId = 2,
                ParkingSpotId = 1,
                Status = "Pending",
                StartTime = DateTime.UtcNow.AddHours(1),
                EndTime = DateTime.UtcNow.AddHours(2)
            };

            var ex = Assert.Throws<UserException>(() => service.BeforeUpdate(new ReservationUpdateRequest(), entity));
            Assert.Equal("Forbidden", ex.Message);
        }

        [Fact]
        public void BeforeUpdate_ShouldThrow_WhenUpdatedTimeOverlapsAnotherReservation()
        {
            var context = GetInMemoryContext();
            var service = new ReservationService(
                context,
                GetMockMapper(),
                TestClaimsHelper.CreateAccessor(userId: 1),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var now = DateTime.UtcNow;
            var entity = new EasyPark.Services.Database.Reservation
            {
                Id = 1,
                UserId = 1,
                ParkingSpotId = 10,
                Status = "Pending",
                StartTime = now.AddHours(1),
                EndTime = now.AddHours(2)
            };
            context.Reservations.Add(entity);
            context.Reservations.Add(new EasyPark.Services.Database.Reservation
            {
                Id = 2,
                UserId = 2,
                ParkingSpotId = 10,
                Status = "Active",
                StartTime = now.AddHours(3),
                EndTime = now.AddHours(5),
                CreatedAt = now
            });
            context.SaveChanges();

            var request = new ReservationUpdateRequest
            {
                StartTime = now.AddHours(4),
                EndTime = now.AddHours(6)
            };

            var ex = Assert.Throws<UserException>(() => service.BeforeUpdate(request, entity));
            Assert.Contains("already reserved for this time period", ex.Message);
        }

        [Fact]
        public void GetById_ShouldThrowForbidden_WhenNonOwnerAndNonAdmin()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new ReservationService(
                context,
                mapper,
                TestClaimsHelper.CreateAccessor(userId: 1),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var owner = new EasyPark.Services.Database.User
            {
                Id = 2, Username = "owner", Email = "o@e.com", FirstName = "O", LastName = "W",
                PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1)
            };
            var creator = new EasyPark.Services.Database.User
            {
                Id = 1, Username = "creator", Email = "c@e.com", FirstName = "C", LastName = "R",
                PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1)
            };
            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, PricePerHour = 5m, PriceRegular = 5m, CreatedBy = 1, CreatedByUser = creator };
            var spot = new EasyPark.Services.Database.ParkingSpot { Id = 1, SpotNumber = "R1", SpotType = "Regular", ParkingLocationId = 1, IsActive = true, ParkingLocation = location };
            var reservation = new EasyPark.Services.Database.Reservation
            {
                Id = 100,
                UserId = 2,
                ParkingSpotId = 1,
                Status = "Pending",
                StartTime = DateTime.UtcNow.AddHours(1),
                EndTime = DateTime.UtcNow.AddHours(2),
                TotalPrice = 10m
            };
            context.Users.AddRange(creator, owner);
            context.ParkingLocations.Add(location);
            context.ParkingSpots.Add(spot);
            context.Reservations.Add(reservation);
            context.SaveChanges();

            var ex = Assert.Throws<UserException>(() => service.GetById(100));
            Assert.Equal("Forbidden", ex.Message);
        }

        [Fact]
        public void GetById_ShouldReturnReservation_ForAdminUser()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new ReservationService(
                context,
                mapper,
                CreateAdminAccessor(userId: 999),
                new Mock<IReservationHistoryService>().Object,
                new Mock<IRabbitMQService>().Object);

            var owner = new EasyPark.Services.Database.User
            {
                Id = 2, Username = "owner", Email = "o@e.com", FirstName = "O", LastName = "W",
                PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1)
            };
            var creator = new EasyPark.Services.Database.User
            {
                Id = 1, Username = "creator", Email = "c@e.com", FirstName = "C", LastName = "R",
                PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1)
            };
            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1, PricePerHour = 5m, PriceRegular = 5m, CreatedBy = 1, CreatedByUser = creator };
            var spot = new EasyPark.Services.Database.ParkingSpot { Id = 1, SpotNumber = "R1", SpotType = "Regular", ParkingLocationId = 1, IsActive = true, ParkingLocation = location };
            var reservation = new EasyPark.Services.Database.Reservation
            {
                Id = 101,
                UserId = 2,
                ParkingSpotId = 1,
                Status = "Pending",
                StartTime = DateTime.UtcNow.AddHours(1),
                EndTime = DateTime.UtcNow.AddHours(2),
                TotalPrice = 10m
            };
            context.Users.AddRange(creator, owner);
            context.ParkingLocations.Add(location);
            context.ParkingSpots.Add(spot);
            context.Reservations.Add(reservation);
            context.SaveChanges();

            var result = service.GetById(101);
            Assert.Equal(101, result.Id);
            Assert.Equal(2, result.UserId);
        }
    }
}
