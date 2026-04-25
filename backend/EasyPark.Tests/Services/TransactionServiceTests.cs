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
    public class TransactionServiceTests
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
            mockMapper.Setup(m => m.Map<EasyPark.Model.Models.Transaction>(It.IsAny<EasyPark.Services.Database.Transaction>()))
                .Returns((EasyPark.Services.Database.Transaction source) => new EasyPark.Model.Models.Transaction
                {
                    Id = source.Id,
                    UserId = source.UserId,
                    Amount = source.Amount,
                    Status = source.Status,
                    PaymentMethod = source.PaymentMethod
                });
            return mockMapper.Object;
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenAmountIsZeroOrNegative()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new TransactionService(context, mapper, httpContextAccessor);

            var request = new TransactionInsertRequest { Amount = 0, PaymentMethod = "Stripe" };
            var entity = new EasyPark.Services.Database.Transaction();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Equal("Amount must be greater than 0", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldThrowException_WhenPaymentMethodIsInvalid()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new TransactionService(context, mapper, httpContextAccessor);

            var request = new TransactionInsertRequest { Amount = 10, PaymentMethod = "Bitcoin" };
            var entity = new EasyPark.Services.Database.Transaction();

            // Act & Assert
            var exception = Assert.Throws<UserException>(() => service.BeforeInsert(request, entity));
            Assert.Contains("Invalid payment method", exception.Message);
        }

        [Fact]
        public void BeforeInsert_ShouldSetRequiredFields()
        {
            // Arrange
            var context = GetInMemoryContext();
            var mapper = GetMockMapper();
            var httpContextAccessor = TestClaimsHelper.CreateAccessor();
            var service = new TransactionService(context, mapper, httpContextAccessor);

            var user = new EasyPark.Services.Database.User { Id = 1, Username = "testuser", Email = "t@e.com", FirstName = "F", LastName = "L", PasswordHash = "h", PasswordSalt = "s", BirthDate = new DateOnly(1990, 1, 1) };
            context.Users.Add(user);
            context.SaveChanges();

            var request = new TransactionInsertRequest { Amount = 100, PaymentMethod = "Stripe", Currency = "BAM" };
            var entity = new EasyPark.Services.Database.Transaction();

            // Act
            service.BeforeInsert(request, entity);

            // Assert
            Assert.Equal(1, entity.UserId);
            Assert.Equal("Pending", entity.Status);
            Assert.Equal("BAM", entity.Currency);
        }
    }
}
