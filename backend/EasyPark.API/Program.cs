using Mapster;
using EasyPark.API.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using QuestPDF.Infrastructure;
using Microsoft.EntityFrameworkCore;
using EasyPark.Model.Requests;
using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Services;
using EasyPark.API.Filters;
using EasyPark.Services.BackgroundServices;
using Hangfire;
using System.Text;
using ReservationUpdateRequest = EasyPark.Model.Requests.ReservationUpdateRequest;
using ReviewUpdateRequest = EasyPark.Model.Requests.ReviewUpdateRequest;
using TransactionUpdateRequest = EasyPark.Model.Requests.TransactionUpdateRequest;

QuestPDF.Settings.License = LicenseType.Community;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpContextAccessor();

// Add services to the container.
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IParkingLocationService, ParkingLocationService>();
builder.Services.AddScoped<IParkingSpotService, ParkingSpotService>();
builder.Services.AddScoped<IReservationService, ReservationService>();
builder.Services.AddScoped<IReviewService, ReviewService>();
builder.Services.AddScoped<IBookmarkService, BookmarkService>();
builder.Services.AddScoped<ITransactionService, TransactionService>();
builder.Services.AddScoped<IReportService, ReportService>();
builder.Services.AddScoped<IReservationHistoryService, ReservationHistoryService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddSingleton<IRabbitMQService, RabbitMQService>();
builder.Services.AddScoped<EasyPark.API.Filters.ExceptionFilter>();
builder.Services.AddScoped<ReservationStatusUpdater>();
builder.Services.AddSingleton<ITokenSecurityService, TokenSecurityService>();

builder.Services.AddControllers(x =>
{
    x.Filters.Add<ExceptionFilter>();
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("basicAuth", new Microsoft.OpenApi.Models.OpenApiSecurityScheme()
    {
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT"
    });

    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement()
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference{Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme, Id = "basicAuth"}
            },
            new string[]{}
    } });
});

var connectionString = Environment.GetEnvironmentVariable("_connectionString")
    ?? Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
    ?? builder.Configuration.GetConnectionString("DefaultConnection")
    ?? builder.Configuration.GetConnectionString("IB220016")
    ?? throw new InvalidOperationException("Database connection string is not configured. Set '_connectionString' or 'ConnectionStrings__DefaultConnection'.");
builder.Services.AddDbContext<EasyParkDbContext>(options =>
    options.UseSqlServer(connectionString));

builder.Services.AddHangfire(configuration => configuration
    .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
    .UseSimpleAssemblyNameTypeSerializer()
    .UseRecommendedSerializerSettings()
    .UseSqlServerStorage(connectionString));

builder.Services.AddHangfireServer();

builder.Services.AddMapster();

var stripeSecretKey = Environment.GetEnvironmentVariable("_stripe")
    ?? builder.Configuration["Stripe:SecretKey"]
    ?? throw new InvalidOperationException("Stripe secret key is not configured. Set '_stripe' env var or 'Stripe:SecretKey' in appsettings.");
Stripe.StripeConfiguration.ApiKey = stripeSecretKey;

TypeAdapterConfig<UserUpdateRequest, EasyPark.Services.Database.User>
    .NewConfig()
    .IgnoreNullValues(true);

TypeAdapterConfig<EasyPark.Services.Database.User, EasyPark.Model.Models.User>.NewConfig()
    .Map(dest => dest.Roles, src => src.UserRoles.Select(ur => ur.Role.Name).ToList());

TypeAdapterConfig<ParkingLocationUpdateRequest, EasyPark.Services.Database.ParkingLocation>
    .NewConfig()
    .IgnoreNullValues(true)
    .Ignore(dest => dest.Photo);
// TotalSpots doesn't exist in DB model - Mapster will automatically skip it

TypeAdapterConfig<ParkingLocationInsertRequest, EasyPark.Services.Database.ParkingLocation>
    .NewConfig()
    .Ignore(dest => dest.Photo);
// TotalSpots doesn't exist in DB model - Mapster will automatically skip it

TypeAdapterConfig<EasyPark.Services.Database.ParkingLocation, EasyPark.Model.Models.ParkingLocation>.NewConfig()
    .Map(
        dest => dest.CreatedByName,
        src => src.CreatedByUser != null
            ? (src.CreatedByUser.FirstName + " " + src.CreatedByUser.LastName).Trim()
            : string.Empty)
    .Map(dest => dest.CityName, src => src.City != null ? src.City.Name : string.Empty)
    .Map(dest => dest.Photo, src => src.Photo != null ? Convert.ToBase64String(src.Photo) : null);

TypeAdapterConfig<ParkingSpotUpdateRequest, EasyPark.Services.Database.ParkingSpot>
    .NewConfig()
    .IgnoreNullValues(true);

TypeAdapterConfig<EasyPark.Services.Database.ParkingSpot, EasyPark.Model.Models.ParkingSpot>.NewConfig()
    .Map(dest => dest.ParkingLocationName, src => src.ParkingLocation.Name);

TypeAdapterConfig<ReservationUpdateRequest, EasyPark.Services.Database.Reservation>
    .NewConfig()
    .IgnoreNullValues(true);

TypeAdapterConfig<EasyPark.Services.Database.Reservation, EasyPark.Model.Models.Reservation>.NewConfig()
    .Map(dest => dest.UserFullName, src => src.User.FirstName + " " + src.User.LastName)
    .Map(dest => dest.ParkingSpotNumber, src => src.ParkingSpot.SpotNumber)
    .Map(dest => dest.ParkingLocationName, src => src.ParkingSpot.ParkingLocation.Name);

TypeAdapterConfig<ReviewUpdateRequest, EasyPark.Services.Database.Review>
    .NewConfig()
    .IgnoreNullValues(true);

TypeAdapterConfig<EasyPark.Services.Database.Review, EasyPark.Model.Models.Review>.NewConfig()
    .Map(dest => dest.UserFullName, src => src.User.FirstName + " " + src.User.LastName)
    .Map(dest => dest.ParkingLocationName, src => src.ParkingLocation.Name);

TypeAdapterConfig<EasyPark.Services.Database.Bookmark, EasyPark.Model.Models.Bookmark>.NewConfig()
    .Map(dest => dest.UserFullName, src => src.User.FirstName + " " + src.User.LastName)
    .Map(dest => dest.ParkingLocationName, src => src.ParkingLocation.Name);

TypeAdapterConfig<TransactionUpdateRequest, EasyPark.Services.Database.Transaction>
    .NewConfig()
    .IgnoreNullValues(true);

TypeAdapterConfig<EasyPark.Services.Database.Transaction, EasyPark.Model.Models.Transaction>.NewConfig()
    .Map(dest => dest.UserFullName, src => src.User.FirstName + " " + src.User.LastName)
    .Map(dest => dest.Type, src => src.ReservationId != null ? "Debit" : "Credit");

TypeAdapterConfig<EasyPark.Services.Database.Report, EasyPark.Model.Models.Report>.NewConfig()
    .Map(dest => dest.ParkingLocationName, src => src.ParkingLocation != null ? src.ParkingLocation.Name : null)
    .Map(dest => dest.UserFullName, src => src.User != null ? src.User.FirstName + " " + src.User.LastName : null);

TypeAdapterConfig<EasyPark.Services.Database.ReservationHistory, EasyPark.Model.Models.ReservationHistory>.NewConfig()
    .Map(dest => dest.UserFullName, src => src.User != null ? src.User.FirstName + " " + src.User.LastName : null);

TypeAdapterConfig<NotificationUpdateRequest, EasyPark.Services.Database.Notification>
    .NewConfig()
    .IgnoreNullValues(true);

var jwtKey = Environment.GetEnvironmentVariable("_jwtKey") ?? builder.Configuration["Jwt:Key"];
var jwtIssuer = Environment.GetEnvironmentVariable("_jwtIssuer") ?? builder.Configuration["Jwt:Issuer"] ?? "easypark-api";
var jwtAudience = Environment.GetEnvironmentVariable("_jwtAudience") ?? builder.Configuration["Jwt:Audience"] ?? "easypark-clients";
if (string.IsNullOrWhiteSpace(jwtKey))
{
    throw new InvalidOperationException("JWT key is not configured. Set '_jwtKey' env var or 'Jwt:Key' in appsettings.");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ClockSkew = TimeSpan.Zero
        };

        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                var authHeader = context.Request.Headers.Authorization.ToString();
                var token = authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                    ? authHeader["Bearer ".Length..].Trim()
                    : string.Empty;

                if (!string.IsNullOrWhiteSpace(token))
                {
                    var tokenSecurity = context.HttpContext.RequestServices.GetRequiredService<ITokenSecurityService>();
                    if (tokenSecurity.IsJwtRevoked(token))
                    {
                        context.Fail("Token has been revoked.");
                    }
                }

                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        var configuredOrigins = Environment.GetEnvironmentVariable("_corsOrigins")
            ?? builder.Configuration["Cors:Origins"];
        var origins = (configuredOrigins ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (origins.Length == 0)
        {
            throw new InvalidOperationException("CORS origins are not configured. Set '_corsOrigins' (comma separated) or 'Cors:Origins'.");
        }

        var originSet = new HashSet<string>(origins, StringComparer.OrdinalIgnoreCase);
        policy.SetIsOriginAllowed(origin =>
            {
                if (originSet.Contains(origin))
                    return true;

                if (Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                {
                    // Flutter web debug/dev servers often use dynamic localhost ports.
                    if (uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                        uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }

                return false;
            })
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();

// Only HTTP is bound (e.g. Docker ASPNETCORE_URLS=http://+:8080). Redirecting to HTTPS breaks
// browser calls from Flutter web (ERR_EMPTY_RESPONSE / failed fetch).
var aspnetUrls = Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? string.Empty;
var httpOnlyBinding = aspnetUrls.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
    && !aspnetUrls.Contains("https://", StringComparison.OrdinalIgnoreCase);
if (!httpOnlyBinding)
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.UseHangfireDashboard();

using (var scope = app.Services.CreateScope())
{
    var dataContext = scope.ServiceProvider.GetRequiredService<EasyParkDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    
    // Retry logic
    int maxRetries = 10;
    int retryDelaySeconds = 5;
    bool migrationSucceeded = false;
    
    for (int i = 0; i < maxRetries; i++)
    {
        try
        {
            logger.LogInformation($"Attempt to connect to database... (Attempt {i + 1}/{maxRetries})");
            dataContext.Database.Migrate();
            migrationSucceeded = true;
            
            logger.LogInformation("Migrations applied successfully!");
            break;
        }
        catch (Exception ex)
        {
            logger.LogWarning($"Attempt {i + 1} failed: {ex.Message}");
            
            if (i < maxRetries - 1)
            {
                logger.LogInformation($"Waiting {retryDelaySeconds} seconds before next attempt...");
                await Task.Delay(retryDelaySeconds * 1000);
            }
            else
            {
                logger.LogError($"Unable to connect to database after {maxRetries} attempts.");
                throw;
            }
        }
    }
    
    if (migrationSucceeded)
    {
        try
        {
            EasyPark.Services.Database.DbInitializer.Seed(dataContext);
            logger.LogInformation("Seed data added successfully!");
        }
        catch (Exception ex)
        {
            logger.LogError($"Error adding seed data: {ex.Message}");
        }

        RecurringJob.AddOrUpdate<ReservationStatusUpdater>(
            "CheckReservations",
            updater => updater.CheckReservations(),
            Cron.MinuteInterval(30));
        logger.LogInformation("Hangfire recurring job registered.");
    }
}

app.Run();