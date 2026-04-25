using RabbitMQ.Client;
using System.Text;
using Newtonsoft.Json;

namespace EasyPark.Services.Services
{
    public interface IRabbitMQService
    {
        void PublishMessage<T>(string queueName, T message);
    }

    public class RabbitMQService : IRabbitMQService, IDisposable
    {
        private IConnection? _connection;
        private IModel? _channel;

        public RabbitMQService()
        {
            var factory = new ConnectionFactory()
            {
                HostName = Environment.GetEnvironmentVariable("_rabbitMqHost") ?? "localhost",
                UserName = Environment.GetEnvironmentVariable("_rabbitMqUser") ?? "guest",
                Password = Environment.GetEnvironmentVariable("_rabbitMqPassword") ?? "guest",
                Port = int.Parse(Environment.GetEnvironmentVariable("_rabbitMqPort") ?? "5672")
            };

            try
            {
                var connection = factory.CreateConnection();
                _connection = connection;
                _channel = connection.CreateModel();
            }
            catch
            {
                _connection = null;
                _channel = null;
            }
        }

        public virtual void PublishMessage<T>(string queueName, T message)
        {
            if (_channel == null) return;

            _channel.QueueDeclare(queue: queueName, durable: false, exclusive: false, autoDelete: false, arguments: null);

            var json = JsonConvert.SerializeObject(message);
            var body = Encoding.UTF8.GetBytes(json);

            _channel.BasicPublish(exchange: "", routingKey: queueName, basicProperties: null, body: body);
        }

        public void Dispose()
        {
            _channel?.Close();
            _connection?.Close();
        }
    }
}

