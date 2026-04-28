using System;
using System.Collections.Generic;
using System.Linq;
using EasyPark.Model.Models;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Services;
using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;
using EasyPark.Model;

namespace EasyPark.Tests.Services
{
    public class ReservationHistoryServiceTests
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
        public void LogStatusChange_ShouldThrowException_WhenReservationNotFound()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReservationHistoryService(context, mapper, httpContextAccessor);

            var exception = Assert.Throws<UserException>(() => service.LogStatusChange(999, "Pending", "Active"));
            Assert.Equal("Reservation not found", exception.Message);
        }

        [Fact]
        public void LogStatusChange_ShouldCreateHistoryEntry()
        {
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReservationHistoryService(context, mapper, httpContextAccessor);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "testuser", Email = "t@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1) };
            context.Users.Add(user);

            // DB stores UTC in production; DateTime.Now is test-only fixture value.
            var reservation = new EasyPark.Services.Database.Reservation
            {
                Id = 1,
                UserId = 1,
                Status = "Pending",
                StartTime = DateTime.Now,
                EndTime = DateTime.Now.AddHours(1),
                User = user
            };
            context.Reservations.Add(reservation);
            context.SaveChanges();

            service.LogStatusChange(1, "Pending", "Active", "Customer checked in", "Notes here");
            context.SaveChanges();

            var history = context.ReservationHistories.FirstOrDefault(h => h.ReservationId == 1);
            Assert.NotNull(history);
            Assert.Equal("Pending", history.OldStatus);
            Assert.Equal("Active", history.NewStatus);
            Assert.Equal("Customer checked in", history.ChangeReason);
            Assert.Equal("Notes here", history.Notes);
            Assert.Equal(1, history.UserId);
        }
    }
}
