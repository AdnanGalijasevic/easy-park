using EasyPark.Model.Constants;
using EasyPark.Model.Messages;
using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace EasyPark.Services.BackgroundServices
{
    public class ReservationStatusUpdater : IHostedService, IDisposable
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<ReservationStatusUpdater> _logger;
        private Timer? _timer;

        public ReservationStatusUpdater(IServiceProvider serviceProvider, ILogger<ReservationStatusUpdater> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("ReservationStatusUpdater started. Running every 1 minute.");
            _timer = new Timer(_ => CheckReservations(), null, TimeSpan.Zero, TimeSpan.FromMinutes(1));
            return Task.CompletedTask;
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("ReservationStatusUpdater stopping.");
            _timer?.Change(Timeout.Infinite, 0);
            return Task.CompletedTask;
        }

        public void Dispose() => _timer?.Dispose();

        public void CheckReservations()
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<EasyParkDbContext>();
                var rabbitMQService = scope.ServiceProvider.GetRequiredService<IRabbitMQService>();
                var historyService = scope.ServiceProvider.GetRequiredService<IReservationHistoryService>();
                var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

                var now = DateTime.UtcNow;

                var toExpire = context.Reservations
                    .Include(r => r.User)
                    .Include(r => r.ParkingSpot)
                    .ThenInclude(ps => ps.ParkingLocation)
                    .Where(r => r.Status == ReservationStatus.Pending && r.EndTime <= now)
                    .ToList();

                var toComplete = context.Reservations
                    .Include(r => r.User)
                    .Include(r => r.ParkingSpot)
                    .ThenInclude(ps => ps.ParkingLocation)
                    .Where(r => (r.Status == ReservationStatus.Confirmed || r.Status == ReservationStatus.Active) && r.EndTime <= now)
                    .ToList();

                foreach (var res in toExpire)
                {
                    var oldStatus = res.Status;
                    res.Status = ReservationStatus.Expired;
                    res.UpdatedAt = now;
                    historyService.LogStatusChange(res.Id, oldStatus, ReservationStatus.Expired, "Automatically expired by background job");

                    notificationService.CreateNotification(
                        res.UserId,
                        "Reservation Expired",
                        $"Your reservation at {res.ParkingSpot.ParkingLocation.Name} (Spot {res.ParkingSpot.SpotNumber}) has expired.",
                        "Alert");

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

                foreach (var res in toComplete)
                {
                    var oldStatus = res.Status;
                    res.Status = ReservationStatus.Completed;
                    res.UpdatedAt = now;
                    historyService.LogStatusChange(res.Id, oldStatus, ReservationStatus.Completed, "Automatically completed by background job");

                    notificationService.CreateNotification(
                        res.UserId,
                        "Reservation Completed",
                        $"Your reservation at {res.ParkingSpot.ParkingLocation.Name} (Spot {res.ParkingSpot.SpotNumber}) is completed.",
                        "Success");

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

                var endingSoon = context.Reservations
                    .Include(r => r.User)
                    .Include(r => r.ParkingSpot)
                    .ThenInclude(ps => ps.ParkingLocation)
                    .Where(r => (r.Status == ReservationStatus.Confirmed || r.Status == ReservationStatus.Active)
                                && EF.Functions.DateDiffMinute(now, r.EndTime) > 0
                                && EF.Functions.DateDiffMinute(now, r.EndTime) <= 30
                                && !r.EndingSoonNotificationSent)
                    .ToList();

                foreach (var res in endingSoon)
                {
                    res.EndingSoonNotificationSent = true;
                    res.UpdatedAt = now;

                    notificationService.CreateNotification(
                        res.UserId,
                        "Reservation Ending Soon",
                        $"Your reservation at {res.ParkingSpot.ParkingLocation.Name} (Spot {res.ParkingSpot.SpotNumber}) will end in less than 30 minutes.",
                        "Info");

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

                if (toExpire.Any() || toComplete.Any() || endingSoon.Any())
                {
                    context.SaveChanges();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ReservationStatusUpdater failed during scheduled run.");
            }
        }
    }
}
