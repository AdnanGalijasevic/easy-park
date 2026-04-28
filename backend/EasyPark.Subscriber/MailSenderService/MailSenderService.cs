using MimeKit;
using MailKit.Net.Smtp;
using EasyPark.Subscriber;
using Microsoft.Extensions.Logging;

namespace EasyPark.Subscriber.MailSenderService
{
    public class MailSenderService
    {
        private readonly ILogger<MailSenderService> _logger;
        private readonly string _fromAddress;
        private readonly string _password;
        private readonly string _host;
        private readonly int _port;
        private readonly bool _enableSsl;
        private readonly string _displayName;

        public MailSenderService(ILogger<MailSenderService> logger)
        {
            _logger = logger;
            _fromAddress = GetRequiredEnvironmentValue("_fromAddress");
            _password = GetRequiredEnvironmentValue("_password");
            _host = GetRequiredEnvironmentValue("_host");
            _port = GetRequiredEnvironmentInt("_port");
            _enableSsl = GetRequiredEnvironmentBool("_enableSSL");
            _displayName = GetRequiredEnvironmentValue("_displayName");
        }

        public async Task SendEmail(Email emailObj)
        {
            if (emailObj == null) return;

            var email = new MimeMessage();

            email.From.Add(new MailboxAddress(_displayName, _fromAddress));
            email.To.Add(new MailboxAddress(emailObj.ReceiverName, emailObj.EmailTo));

            email.Subject = emailObj.Subject;
            email.Body = new TextPart(MimeKit.Text.TextFormat.Html)
            {
                Text = emailObj.Message
            };

            try
            {
                _logger.LogInformation("Connecting to SMTP server...");

                using (var smtp = new SmtpClient())
                {
                    await smtp.ConnectAsync(_host, _port, _enableSsl);
                    _logger.LogInformation("Connection to SMTP successful.");

                    await smtp.AuthenticateAsync(_fromAddress, _password);
                    _logger.LogInformation("Successfully authenticated to SMTP.");

                    await smtp.SendAsync(email);

                    await smtp.DisconnectAsync(true);
                }
                _logger.LogInformation("Mail successfully sent.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "SMTP send failed.");
                return;
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

        private static int GetRequiredEnvironmentInt(string key)
        {
            var value = GetRequiredEnvironmentValue(key);
            if (!int.TryParse(value, out var parsed))
            {
                throw new InvalidOperationException($"Invalid integer environment variable '{key}'.");
            }

            return parsed;
        }

        private static bool GetRequiredEnvironmentBool(string key)
        {
            var value = GetRequiredEnvironmentValue(key);
            if (!bool.TryParse(value, out var parsed))
            {
                throw new InvalidOperationException($"Invalid boolean environment variable '{key}'.");
            }

            return parsed;
        }
    }
}

