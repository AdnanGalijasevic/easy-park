using System;
using System.Collections.Generic;
using System.Linq;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
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
    public class ReportServiceTests
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
        public void BeforeInsert_ShouldThrowException_WhenReportTypeIsInvalid()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReportService(context, mapper, httpContextAccessor);

            var request = new ReportInsertRequest { ReportType = "Hourly", PeriodStart = DateTime.Now, PeriodEnd = DateTime.Now.AddDays(1) };
            var entity = new EasyPark.Services.Database.Report();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Contains("Invalid report type", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenPeriodEndIsBeforeStart()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReportService(context, mapper, httpContextAccessor);

            var request = new ReportInsertRequest { ReportType = "Daily", PeriodStart = DateTime.Now, PeriodEnd = DateTime.Now.AddDays(-1) };
            var entity = new EasyPark.Services.Database.Report();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("PeriodEnd must be after PeriodStart", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldCalculateRevenueAndReservations()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new ReportService(context, mapper, httpContextAccessor);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "testuser", Email = "t@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1) };
            context.Users.Add(user);

            var start = DateTime.UtcNow.AddDays(-1);
            var end = DateTime.UtcNow.AddDays(1);

            // Add some completed reservations and transactions
            context.Reservations.Add(new EasyPark.Services.Database.Reservation { Id = 1, Status = "Completed", StartTime = DateTime.UtcNow, EndTime = DateTime.UtcNow.AddHours(1), TotalPrice = 10, UserId = 1 });
            context.Transactions.Add(new EasyPark.Services.Database.Transaction { Id = 1, Status = "Completed", Amount = 10, Currency = "BAM", PaymentMethod = "Stripe", CreatedAt = DateTime.UtcNow, UserId = 1 });
            context.SaveChanges();

            var request = new ReportInsertRequest { ReportType = "Daily", PeriodStart = start, PeriodEnd = end };
            var entity = new EasyPark.Services.Database.Report();

            // Act
            service.BeforeInsert(request, entity);

            // Assert
            Assert.Equal(10, entity.TotalRevenue);
            Assert.Equal(1, entity.TotalReservations);
            Assert.Equal(1, entity.UserId);
        }
    }
}
