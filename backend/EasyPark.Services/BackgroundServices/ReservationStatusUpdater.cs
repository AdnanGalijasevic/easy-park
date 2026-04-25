using EasyPark.Model.Messages;
using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Linq;

namespace EasyPark.Services.BackgroundServices
{
    public class ReservationStatusUpdater
    {
        private readonly IServiceProvider _serviceProvider;

        public ReservationStatusUpdater(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider;
        }

        public void CheckReservations()
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<EasyParkDbContext>();
            var rabbitMQService = scope.ServiceProvider.GetRequiredService<IRabbitMQService>();
            var historyService = scope.ServiceProvider.GetRequiredService<IReservationHistoryService>();

            var now = DateTime.UtcNow;

            // 1. Mark Expired
            var toExpire = context.Reservations
                .Include(r => r.User)
                .Include(r => r.ParkingSpot)
                .ThenInclude(ps => ps.ParkingLocation)
                .Where(r => (r.Status == "Pending" || r.Status == "Active") && r.EndTime <= now)
                .ToList();

            foreach (var res in toExpire)
            {
                var oldStatus = res.Status;
                res.Status = "Expired";
                res.UpdatedAt = now;
                historyService.LogStatusChange(res.Id, oldStatus, "Expired", "Automatically expired by background job");

                // 1. App Notification
                var appNotification = new Database.Notification
                {
                    UserId = res.UserId,
                    Title = "Reservation Expired",
                    Message = $"Your reservation at {res.ParkingSpot.ParkingLocation.Name} (Spot {res.ParkingSpot.SpotNumber}) has expired.",
                    Type = "Alert",
                    CreatedAt = now,
                    IsRead = false
                };
                context.Notifications.Add(appNotification);

                // 2. Email Notification
                var message = new ReservationCompleted
                {
                    ReservationId = res.Id,
                    Email = res.User.Email,
                    Name = $"{res.User.FirstName} {res.User.LastName}",
                    ParkingLocationName = res.ParkingSpot.ParkingLocation.Name,
                    SpotNumber = res.ParkingSpot.SpotNumber,
                    StartTime = res.StartTime,
                    EndTime = res.EndTime,
                    TotalPrice = res.TotalPrice
                };
                rabbitMQService.PublishMessage("easypark_reservation_completed", message);
            }

            // 2. Notify Ending Soon (e.g. within 30 minutes)
            var notificationThreshold = now.AddMinutes(30);
            var endingSoon = context.Reservations
                .Include(r => r.User)
                .Include(r => r.ParkingSpot)
                .ThenInclude(ps => ps.ParkingLocation)
                .Where(r => r.Status == "Active" 
                            && r.EndTime <= notificationThreshold 
                            && r.EndTime > now
                            && !r.EndingSoonNotificationSent)
                .ToList();

            foreach (var res in endingSoon)
            {
                res.EndingSoonNotificationSent = true;
                res.UpdatedAt = now;

                // 1. App Notification
                var appNotification = new Database.Notification
                {
                    UserId = res.UserId,
                    Title = "Reservation Ending Soon",
                    Message = $"Your reservation at {res.ParkingSpot.ParkingLocation.Name} (Spot {res.ParkingSpot.SpotNumber}) will end in 30 minutes.",
                    Type = "Info",
                    CreatedAt = now,
                    IsRead = false
                };
                context.Notifications.Add(appNotification);

                // 2. Email Notification
                var message = new ReservationEndingSoon
                {
                    ReservationId = res.Id,
                    Email = res.User.Email,
                    Name = $"{res.User.FirstName} {res.User.LastName}",
                    ParkingLocationName = res.ParkingSpot.ParkingLocation.Name,
                    SpotNumber = res.ParkingSpot.SpotNumber,
                    EndTime = res.EndTime
                };
                rabbitMQService.PublishMessage("easypark_reservation_ending_soon", message);
            }

            if (toExpire.Any() || endingSoon.Any())
            {
                context.SaveChanges();
            }
        }
    }
}
