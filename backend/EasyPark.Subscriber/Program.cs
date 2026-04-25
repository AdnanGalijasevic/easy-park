using DotNetEnv;
using EasyPark.Subscriber.MailSenderService;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using Newtonsoft.Json;
using EasyPark.Model.Messages;
using EasyPark.Subscriber;

Env.Load();
var mailSender = new MailSenderService();

Console.WriteLine("Starting EasyPark Mail Listener...");

var reservationCreatedTemplatePath = Path.Combine(AppContext.BaseDirectory, "Templates", "ReservationCreated.html");
var reservationCancelledTemplatePath = Path.Combine(AppContext.BaseDirectory, "Templates", "ReservationCancelled.html");
var reservationCompletedTemplatePath = Path.Combine(AppContext.BaseDirectory, "Templates", "ReservationCompleted.html");
var reservationEndingSoonTemplatePath = Path.Combine(AppContext.BaseDirectory, "Templates", "ReservationEndingSoon.html");
var passwordResetTemplatePath = Path.Combine(AppContext.BaseDirectory, "Templates", "PasswordReset.html");

var reservationCreatedTemplate = await File.ReadAllTextAsync(reservationCreatedTemplatePath);
var reservationCancelledTemplate = await File.ReadAllTextAsync(reservationCancelledTemplatePath);
var reservationCompletedTemplate = await File.ReadAllTextAsync(reservationCompletedTemplatePath);
var reservationEndingSoonTemplate = await File.ReadAllTextAsync(reservationEndingSoonTemplatePath);
var passwordResetTemplate = await File.ReadAllTextAsync(passwordResetTemplatePath);

var factory = new ConnectionFactory()
{
    HostName = Environment.GetEnvironmentVariable("_rabbitMqHost") ?? "localhost",
    UserName = Environment.GetEnvironmentVariable("_rabbitMqUser") ?? "guest",
    Password = Environment.GetEnvironmentVariable("_rabbitMqPassword") ?? "guest",
    Port = int.Parse(Environment.GetEnvironmentVariable("_rabbitMqPort") ?? "5672")
};

using var connection = factory.CreateConnection();
using var channel = connection.CreateModel();

string[] queues = { "easypark_reservation_created", "easypark_reservation_cancelled", "easypark_reservation_completed", "easypark_reservation_ending_soon", "easypark_password_reset" };
foreach (var q in queues)
{
    channel.QueueDeclare(queue: q, durable: false, exclusive: false, autoDelete: false, arguments: null);
}

var consumer = new EventingBasicConsumer(channel);
consumer.Received += async (sender, args) =>
{
    var messageBody = Encoding.UTF8.GetString(args.Body.ToArray());
    try
    {
        switch (args.RoutingKey)
        {
            case "easypark_reservation_created":
                var created = JsonConvert.DeserializeObject<ReservationCreated>(messageBody);
                if (created != null)
                {
                    Console.WriteLine($"Reservation created: {created.ReservationId}");
                    var filledHtml = reservationCreatedTemplate
                        .Replace("{{Name}}", created.Name)
                        .Replace("{{ReservationId}}", created.ReservationId.ToString())
                        .Replace("{{ParkingLocationName}}", created.ParkingLocationName)
                        .Replace("{{SpotNumber}}", created.SpotNumber)
                        .Replace("{{StartTime}}", created.StartTime.ToString("yyyy-MM-dd HH:mm"))
                        .Replace("{{EndTime}}", created.EndTime.ToString("yyyy-MM-dd HH:mm"))
                        .Replace("{{TotalPrice}}", created.TotalPrice.ToString("F2"))
                        .Replace("{{QRCode}}", created.QRCode);

                    var email = new Email
                    {
                        EmailTo = created.Email,
                        ReceiverName = created.Name ?? "Customer",
                        Subject = "Your EasyPark Reservation is Confirmed!",
                        Message = filledHtml
                    };
                    await mailSender.SendEmail(email);
                }
                break;

            case "easypark_reservation_cancelled":
                var cancelled = JsonConvert.DeserializeObject<ReservationCancelled>(messageBody);
                if (cancelled != null)
                {
                    Console.WriteLine($"Reservation cancelled: {cancelled.ReservationId}");
                    var filledHtml = reservationCancelledTemplate
                        .Replace("{{Name}}", cancelled.Name)
                        .Replace("{{ReservationId}}", cancelled.ReservationId.ToString())
                        .Replace("{{ParkingLocationName}}", cancelled.ParkingLocationName)
                        .Replace("{{SpotNumber}}", cancelled.SpotNumber)
                        .Replace("{{StartTime}}", cancelled.StartTime.ToString("yyyy-MM-dd HH:mm"))
                        .Replace("{{EndTime}}", cancelled.EndTime.ToString("yyyy-MM-dd HH:mm"))
                        .Replace("{{TotalPrice}}", cancelled.TotalPrice.ToString("F2"))
                        .Replace("{{CancellationReason}}", cancelled.CancellationReason ?? "");

                    var email = new Email
                    {
                        EmailTo = cancelled.Email,
                        ReceiverName = cancelled.Name ?? "Customer",
                        Subject = "Your EasyPark Reservation Has Been Cancelled",
                        Message = filledHtml
                    };
                    await mailSender.SendEmail(email);
                }
                break;

            case "easypark_reservation_completed":
                var completed = JsonConvert.DeserializeObject<ReservationCompleted>(messageBody);
                if (completed != null)
                {
                    Console.WriteLine($"Reservation completed: {completed.ReservationId}");
                    var filledHtml = reservationCompletedTemplate
                        .Replace("{{Name}}", completed.Name)
                        .Replace("{{ReservationId}}", completed.ReservationId.ToString())
                        .Replace("{{ParkingLocationName}}", completed.ParkingLocationName)
                        .Replace("{{SpotNumber}}", completed.SpotNumber)
                        .Replace("{{StartTime}}", completed.StartTime.ToString("yyyy-MM-dd HH:mm"))
                        .Replace("{{EndTime}}", completed.EndTime.ToString("yyyy-MM-dd HH:mm"))
                        .Replace("{{TotalPrice}}", completed.TotalPrice.ToString("F2"));

                    var email = new Email
                    {
                        EmailTo = completed.Email,
                        ReceiverName = completed.Name ?? "Customer",
                        Subject = "Your EasyPark Reservation is Complete",
                        Message = filledHtml
                    };
                    await mailSender.SendEmail(email);
                }
                break;

            case "easypark_reservation_ending_soon":
                var endingSoon = JsonConvert.DeserializeObject<ReservationEndingSoon>(messageBody);
                if (endingSoon != null)
                {
                    Console.WriteLine($"Reservation ending soon: {endingSoon.ReservationId}");
                    var filledHtml = reservationEndingSoonTemplate
                        .Replace("{{Name}}", endingSoon.Name)
                        .Replace("{{ReservationId}}", endingSoon.ReservationId.ToString())
                        .Replace("{{ParkingLocationName}}", endingSoon.ParkingLocationName)
                        .Replace("{{SpotNumber}}", endingSoon.SpotNumber)
                        .Replace("{{EndTime}}", endingSoon.EndTime.ToString("yyyy-MM-dd HH:mm"));

                    var email = new Email
                    {
                        EmailTo = endingSoon.Email,
                        ReceiverName = endingSoon.Name ?? "Customer",
                        Subject = "Your EasyPark Reservation is Ending Soon",
                        Message = filledHtml
                    };
                    await mailSender.SendEmail(email);
                }
                break;

            case "easypark_password_reset":
                var pwReset = JsonConvert.DeserializeObject<EasyPark.Model.Messages.PasswordResetRequested>(messageBody);
                if (pwReset != null)
                {
                    Console.WriteLine($"Password reset requested for: {pwReset.Email}");
                    var filledHtml = passwordResetTemplate
                        .Replace("{{Name}}", pwReset.Name)
                        .Replace("{{ResetToken}}", pwReset.ResetToken);

                    var email = new Email
                    {
                        EmailTo = pwReset.Email,
                        ReceiverName = pwReset.Name,
                        Subject = "EasyPark — Password Reset Request",
                        Message = filledHtml
                    };
                    await mailSender.SendEmail(email);
                }
                break;

            default:
                Console.WriteLine($"Unknown routing key: {args.RoutingKey}");
                break;
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error processing message from queue {args.RoutingKey}: {ex}");
    }
};

foreach (var q in queues)
{
    channel.BasicConsume(queue: q, autoAck: true, consumer: consumer);
}

Console.WriteLine("Listening for all messages...");
await Task.Delay(Timeout.InfiniteTimeSpan);
