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
    public class ParkingSpotServiceTests
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
            mockMapper.Setup(m => m.Map<EasyPark.Model.Models.ParkingSpot>(It.IsAny<EasyPark.Services.Database.ParkingSpot>()))
                .Returns((EasyPark.Services.Database.ParkingSpot source) => new EasyPark.Model.Models.ParkingSpot
                {
                    Id = source.Id,
                    ParkingLocationId = source.ParkingLocationId,
                    SpotNumber = source.SpotNumber,
                    SpotType = source.SpotType
                });
            return mockMapper.Object;
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenSpotNumberIsRequired()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new ParkingSpotService(context, mapper);

            var request = new ParkingSpotInsertRequest { SpotNumber = "", SpotType = "Regular" };
            var entity = new EasyPark.Services.Database.ParkingSpot();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("Spot number is required", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenSpotTypeIsInvalid()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new ParkingSpotService(context, mapper);

            var request = new ParkingSpotInsertRequest { SpotNumber = "A1", SpotType = "Helipad" };
            var entity = new EasyPark.Services.Database.ParkingSpot();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Contains("Invalid spot type", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenDuplicateSpotInLocation()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var service = new ParkingSpotService(context, mapper);

            var location = new EasyPark.Services.Database.ParkingLocation { Id = 1, Name = "L", Address = "A", CityId = 1 };
            context.ParkingLocations.Add(location);

            var existingSpot = new EasyPark.Services.Database.ParkingSpot { Id = 1, ParkingLocationId = 1, SpotNumber = "A1", SpotType = "Regular" };
            context.ParkingSpots.Add(existingSpot);
            context.SaveChanges();

            var request = new ParkingSpotInsertRequest { ParkingLocationId = 1, SpotNumber = "A1", SpotType = "Regular" };
            var entity = new EasyPark.Services.Database.ParkingSpot();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Contains("already exists in this parking location", exception.Message);
        }
    }
}
