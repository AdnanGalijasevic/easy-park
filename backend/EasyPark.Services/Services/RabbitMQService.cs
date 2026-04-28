using RabbitMQ.Client;
using RabbitMQ.Client.Exceptions;
using System.Text;
using Newtonsoft.Json;
using Microsoft.Extensions.Logging;

namespace EasyPark.Services.Services
{
    public interface IRabbitMQService
    {
        void PublishMessage<T>(string queueName, T message);
    }

    public class RabbitMQService : IRabbitMQService, IDisposable
    {
        private const string DeadLetterExchange = "easypark.dlx";
        private IConnection? _connection;
        private IModel? _channel;
        private readonly ILogger<RabbitMQService> _logger;

        public RabbitMQService(ILogger<RabbitMQService> logger)
        {
            _logger = logger;
            var host = GetRequiredEnvironmentValue("_rabbitMqHost");
            var user = GetRequiredEnvironmentValue("_rabbitMqUser");
            var password = GetRequiredEnvironmentValue("_rabbitMqPassword");
            var portRaw = GetRequiredEnvironmentValue("_rabbitMqPort");
            if (!int.TryParse(portRaw, out var port))
            {
                throw new InvalidOperationException("Invalid RabbitMQ port. Env var '_rabbitMqPort' must be an integer.");
            }

            var factory = new ConnectionFactory()
            {
                HostName = host,
                UserName = user,
                Password = password,
                Port = port
            };

            try
            {
                var connection = factory.CreateConnection();
                _connection = connection;
                _channel = connection.CreateModel();
                _logger.LogInformation("RabbitMQ connection established.");
            }
            catch (Exception ex)
            {
                _connection = null;
                _channel = null;
                _logger.LogError(ex, "Failed to initialize RabbitMQ connection/channel.");
                throw;
            }
        }

        private static string GetRequiredEnvironmentValue(string key)
        {
            var value = Environment.GetEnvironmentVariable(key);
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException($"Missing required environment variable '{key}'.");
            }

            return value;
        }

        public virtual void PublishMessage<T>(string queueName, T message)
        {
            if (_channel == null)
            {
                var ex = new InvalidOperationException($"RabbitMQ channel unavailable. Queue: {queueName}");
                _logger.LogError(ex, "RabbitMQ publish blocked because channel is null. Queue: {QueueName}", queueName);
                throw ex;
            }

            Exception? lastException = null;
            const int maxAttempts = 3;

            for (var attempt = 1; attempt <= maxAttempts; attempt++)
            {
                try
                {
                    _channel.ExchangeDeclare(exchange: DeadLetterExchange, type: ExchangeType.Direct, durable: true, autoDelete: false);
                    var queueArguments = new Dictionary<string, object>
                    {
                        ["x-dead-letter-exchange"] = DeadLetterExchange,
                        ["x-dead-letter-routing-key"] = queueName
                    };
                    _channel.QueueDeclare(queue: queueName, durable: false, exclusive: false, autoDelete: false, arguments: queueArguments);
                    _channel.QueueDeclare(queue: $"{queueName}.dead", durable: true, exclusive: false, autoDelete: false, arguments: null);
                    _channel.QueueBind(queue: $"{queueName}.dead", exchange: DeadLetterExchange, routingKey: queueName);

                    var json = JsonConvert.SerializeObject(message);
                    var body = Encoding.UTF8.GetBytes(json);

                    _channel.BasicPublish(exchange: "", routingKey: queueName, basicProperties: null, body: body);
                    return;
                }
                catch (OperationInterruptedException ex)
                {
                    lastException = ex;
                    _logger.LogWarning(ex, "RabbitMQ publish interrupted. Queue: {QueueName}. Attempt {Attempt}/{MaxAttempts}", queueName, attempt, maxAttempts);
                }
                catch (Exception ex)
                {
                    lastException = ex;
                    _logger.LogWarning(ex, "RabbitMQ publish failed. Queue: {QueueName}. Attempt {Attempt}/{MaxAttempts}", queueName, attempt, maxAttempts);
                }
            }

            _logger.LogError(lastException, "RabbitMQ publish failed after retries. Queue: {QueueName}", queueName);
            throw new InvalidOperationException($"Failed to publish RabbitMQ message to '{queueName}' after {maxAttempts} attempts.", lastException);
        }

        public void Dispose()
        {
            _channel?.Close();
            _connection?.Close();
        }
    }
}

