using Mapster;
using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;
using EasyPark.Model.Requests;
using EasyPark.Services.Database;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Services;
using EasyPark.API.Filters;
using backend;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpContextAccessor();

// Add services to the container.
builder.Services.AddTransient<IUserService, UserService>();
builder.Services.AddScoped<EasyPark.API.Filters.ExceptionFilter>();

builder.Services.AddControllers(x =>
{
    x.Filters.Add<ExceptionFilter>();
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("basicAuth", new Microsoft.OpenApi.Models.OpenApiSecurityScheme()
    {
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "basic"
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

var connectionString = builder.Configuration.GetConnectionString("EasyParkDB");
builder.Services.AddDbContext<EasyParkDbContext>(options =>
    options.UseSqlServer(connectionString));

builder.Services.AddMapster();

TypeAdapterConfig<UserUpdateRequest, EasyPark.Services.Database.User>
    .NewConfig()
    .IgnoreNullValues(true);

TypeAdapterConfig<EasyPark.Services.Database.User, EasyPark.Model.Models.User>.NewConfig()
    .Map(dest => dest.Roles, src => src.UserRoles.Select(ur => ur.Role.Name).ToList());

builder.Services.AddAuthentication("BasicAuthentication").AddScheme<AuthenticationSchemeOptions, BasicAuthenticationHandler>("BasicAuthentication", null);

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors(
    options => options
        .SetIsOriginAllowed(x => _ = true)
        .AllowAnyMethod()
        .AllowAnyHeader()
        .AllowCredentials()
);

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

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
                Thread.Sleep(retryDelaySeconds * 1000);
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
    }
}

app.Run();