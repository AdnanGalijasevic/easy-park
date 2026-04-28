using EasyPark.Model.Messages;
using Microsoft.Extensions.Hosting;
using MailSvc = EasyPark.Subscriber.MailSenderService.MailSenderService;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Web;

namespace EasyPark.Subscriber
{
    public class MailConsumerService : IHostedService
    {
        private readonly ILogger<MailConsumerService> _logger;
        private readonly MailSvc _mailSender;

        private IConnection? _connection;
        private IModel? _channel;

        private readonly string _reservationCreatedTemplate;
        private readonly string _reservationCancelledTemplate;
        private readonly string _reservationCompletedTemplate;
        private readonly string _reservationEndingSoonTemplate;
        private readonly string _passwordResetTemplate;

        private static readonly string[] Queues =
        {
            "easypark_reservation_created",
            "easypark_reservation_cancelled",
            "easypark_reservation_completed",
            "easypark_reservation_ending_soon",
            "easypark_password_reset"
        };

        private const string DeadLetterExchange = "easypark.dlx";
        private const string DeadLetterQueueSuffix = ".dead";

        public MailConsumerService(ILogger<MailConsumerService> logger, MailSvc mailSender)
        {
            _logger = logger;
            _mailSender = mailSender;

            var basePath = AppContext.BaseDirectory;
            _reservationCreatedTemplate   = File.ReadAllText(Path.Combine(basePath, "Templates", "ReservationCreated.html"));
            _reservationCancelledTemplate = File.ReadAllText(Path.Combine(basePath, "Templates", "ReservationCancelled.html"));
            _reservationCompletedTemplate = File.ReadAllText(Path.Combine(basePath, "Templates", "ReservationCompleted.html"));
            _reservationEndingSoonTemplate = File.ReadAllText(Path.Combine(basePath, "Templates", "ReservationEndingSoon.html"));
            _passwordResetTemplate        = File.ReadAllText(Path.Combine(basePath, "Templates", "PasswordReset.html"));
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Starting EasyPark Mail Listener...");

            var factory = new ConnectionFactory
            {
                HostName = GetRequired("_rabbitMqHost"),
                UserName = GetRequired("_rabbitMqUser"),
                Password = GetRequired("_rabbitMqPassword"),
                Port     = GetRequiredInt("_rabbitMqPort"),
                DispatchConsumersAsync = true
            };

            _connection = factory.CreateConnection();
            _channel    = _connection.CreateModel();

            _channel.ExchangeDeclare(DeadLetterExchange, ExchangeType.Direct, durable: true, autoDelete: false);

            foreach (var q in Queues)
            {
                var args = new Dictionary<string, object>
                {
                    ["x-dead-letter-exchange"]    = DeadLetterExchange,
                    ["x-dead-letter-routing-key"] = q
                };
                _channel.QueueDeclare(q, durable: false, exclusive: false, autoDelete: false, arguments: args);
                var dlq = $"{q}{DeadLetterQueueSuffix}";
                _channel.QueueDeclare(dlq, durable: true, exclusive: false, autoDelete: false, arguments: null);
                _channel.QueueBind(dlq, DeadLetterExchange, q);
            }

            _channel.BasicQos(0, 10, false);

            var consumer = new AsyncEventingBasicConsumer(_channel);
            consumer.Received += OnMessageReceivedAsync;

            foreach (var q in Queues)
                _channel.BasicConsume(q, autoAck: false, consumer: consumer);

            _logger.LogInformation("Listening for all messages...");
            return Task.CompletedTask;
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("MailConsumerService stopping.");
            _channel?.Close();
            _connection?.Close();
            return Task.CompletedTask;
        }

        private async Task OnMessageReceivedAsync(object sender, BasicDeliverEventArgs args)
        {
            var body = Encoding.UTF8.GetString(args.Body.ToArray());
            var retryDelays = new[] { 1000, 2000, 4000, 8000 };
            var processed = false;

            for (var attempt = 0; attempt <= retryDelays.Length; attempt++)
            {
                try
                {
                    await ProcessMessageAsync(args.RoutingKey, body);
                    _channel!.BasicAck(args.DeliveryTag, false);
                    processed = true;
                    break;
                }
                catch (Exception ex)
                {
                    var isLast = attempt == retryDelays.Length;
                    _logger.LogError(ex,
                        "Error processing message. Queue: {Queue}. Attempt: {Attempt}/{Total}.",
                        args.RoutingKey, attempt + 1, retryDelays.Length + 1);

                    if (isLast) break;
                    await Task.Delay(retryDelays[attempt]);
                }
            }

            if (!processed)
            {
                _logger.LogError("Message permanently failed after retries. Queue: {Queue}", args.RoutingKey);
                _channel!.BasicNack(args.DeliveryTag, false, false);
            }
        }

        private async Task ProcessMessageAsync(string routingKey, string messageBody)
        {
            switch (routingKey)
            {
                case "easypark_reservation_created":
                    var created = JsonConvert.DeserializeObject<ReservationCreated>(messageBody);
                    if (created != null)
                    {
                        _logger.LogInformation("Reservation created event. ReservationId: {Id}", created.ReservationId);
                        var html = _reservationCreatedTemplate
                            .Replace("{{Name}}", created.Name)
                            .Replace("{{ReservationId}}", created.ReservationId.ToString())
                            .Replace("{{ParkingLocationName}}", created.ParkingLocationName)
                            .Replace("{{SpotNumber}}", created.SpotNumber)
                            .Replace("{{StartTime}}", created.StartTime.ToString("yyyy-MM-dd HH:mm"))
                            .Replace("{{EndTime}}", created.EndTime.ToString("yyyy-MM-dd HH:mm"))
                            .Replace("{{TotalPrice}}", created.TotalPrice.ToString("F2"))
                            .Replace("{{QRCode}}", created.QRCode)
                            .Replace("{{QRCodeImageSrc}}", BuildQrImageSrc(created.QRCode));
                        await _mailSender.SendEmail(new Email
                        {
                            EmailTo = created.Email,
                            ReceiverName = created.Name ?? "Customer",
                            Subject = "Your EasyPark Reservation is Confirmed!",
                            Message = html
                        });
                    }
                    break;

                case "easypark_reservation_cancelled":
                    var cancelled = JsonConvert.DeserializeObject<ReservationCancelled>(messageBody);
                    if (cancelled != null)
                    {
                        _logger.LogInformation("Reservation cancelled event. ReservationId: {Id}", cancelled.ReservationId);
                        var html = _reservationCancelledTemplate
                            .Replace("{{Name}}", cancelled.Name)
                            .Replace("{{ReservationId}}", cancelled.ReservationId.ToString())
                            .Replace("{{ParkingLocationName}}", cancelled.ParkingLocationName)
                            .Replace("{{SpotNumber}}", cancelled.SpotNumber)
                            .Replace("{{StartTime}}", cancelled.StartTime.ToString("yyyy-MM-dd HH:mm"))
                            .Replace("{{EndTime}}", cancelled.EndTime.ToString("yyyy-MM-dd HH:mm"))
                            .Replace("{{TotalPrice}}", cancelled.TotalPrice.ToString("F2"))
                            .Replace("{{CancellationReason}}", cancelled.CancellationReason ?? "");
                        await _mailSender.SendEmail(new Email
                        {
                            EmailTo = cancelled.Email,
                            ReceiverName = cancelled.Name ?? "Customer",
                            Subject = "Your EasyPark Reservation Has Been Cancelled",
                            Message = html
                        });
                    }
                    break;

                case "easypark_reservation_completed":
                    var completed = JsonConvert.DeserializeObject<ReservationCompleted>(messageBody);
                    if (completed != null)
                    {
                        _logger.LogInformation("Reservation completed event. ReservationId: {Id}", completed.ReservationId);
                        var html = _reservationCompletedTemplate
                            .Replace("{{Name}}", completed.Name)
                            .Replace("{{ReservationId}}", completed.ReservationId.ToString())
                            .Replace("{{ParkingLocationName}}", completed.ParkingLocationName)
                            .Replace("{{SpotNumber}}", completed.SpotNumber)
                            .Replace("{{StartTime}}", completed.StartTime.ToString("yyyy-MM-dd HH:mm"))
                            .Replace("{{EndTime}}", completed.EndTime.ToString("yyyy-MM-dd HH:mm"))
                            .Replace("{{TotalPrice}}", completed.TotalPrice.ToString("F2"));
                        await _mailSender.SendEmail(new Email
                        {
                            EmailTo = completed.Email,
                            ReceiverName = completed.Name ?? "Customer",
                            Subject = "Your EasyPark Reservation is Complete",
                            Message = html
                        });
                    }
                    break;

                case "easypark_reservation_ending_soon":
                    var endingSoon = JsonConvert.DeserializeObject<ReservationEndingSoon>(messageBody);
                    if (endingSoon != null)
                    {
                        _logger.LogInformation("Reservation ending soon event. ReservationId: {Id}", endingSoon.ReservationId);
                        var html = _reservationEndingSoonTemplate
                            .Replace("{{Name}}", endingSoon.Name)
                            .Replace("{{ReservationId}}", endingSoon.ReservationId.ToString())
                            .Replace("{{ParkingLocationName}}", endingSoon.ParkingLocationName)
                            .Replace("{{SpotNumber}}", endingSoon.SpotNumber)
                            .Replace("{{EndTime}}", endingSoon.EndTime.ToString("yyyy-MM-dd HH:mm"));
                        await _mailSender.SendEmail(new Email
                        {
                            EmailTo = endingSoon.Email,
                            ReceiverName = endingSoon.Name ?? "Customer",
                            Subject = "Your EasyPark Reservation is Ending Soon",
                            Message = html
                        });
                    }
                    break;

                case "easypark_password_reset":
                    var pwReset = JsonConvert.DeserializeObject<PasswordResetRequested>(messageBody);
                    if (pwReset != null)
                    {
                        _logger.LogInformation("Password reset event for: {Email}", pwReset.Email);
                        var html = _passwordResetTemplate
                            .Replace("{{Name}}", pwReset.Name)
                            .Replace("{{ResetToken}}", pwReset.ResetToken);
                        await _mailSender.SendEmail(new Email
                        {
                            EmailTo = pwReset.Email,
                            ReceiverName = pwReset.Name,
                            Subject = "EasyPark — Password Reset Request",
                            Message = html
                        });
                    }
                    break;

                default:
                    _logger.LogWarning("Unknown routing key: {RoutingKey}", routingKey);
                    break;
            }
        }

        private static string GetRequired(string key)
        {
            var val = Environment.GetEnvironmentVariable(key);
            if (string.IsNullOrWhiteSpace(val))
                throw new InvalidOperationException($"Missing required environment variable '{key}'.");
            return val;
        }

        private static int GetRequiredInt(string key)
        {
            var val = GetRequired(key);
            if (!int.TryParse(val, out var parsed))
                throw new InvalidOperationException($"Invalid integer environment variable '{key}'.");
            return parsed;
        }

        private static string BuildQrImageSrc(string qrCodeData)
        {
            if (string.IsNullOrWhiteSpace(qrCodeData))
                return string.Empty;

            if (qrCodeData.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
                return qrCodeData;

            var encoded = HttpUtility.UrlEncode(qrCodeData);
            return $"https://api.qrserver.com/v1/create-qr-code/?size=220x220&data={encoded}";
        }
    }
}
