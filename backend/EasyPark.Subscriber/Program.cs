using DotNetEnv;
using EasyPark.Subscriber;
using MailSvc = EasyPark.Subscriber.MailSenderService.MailSenderService;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

Env.Load();

var host = Host.CreateDefaultBuilder(args)
    .ConfigureLogging(logging =>
    {
        logging.ClearProviders();
        logging.AddSimpleConsole(opts => opts.TimestampFormat = "yyyy-MM-dd HH:mm:ss ");
    })
    .ConfigureServices((_, services) =>
    {
        services.AddSingleton<MailSvc>();
        services.AddHostedService<MailConsumerService>();
    })
    .Build();

await host.RunAsync();
