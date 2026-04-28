# EasyPark Backend - Setup Guide

## Option 1: Run with Docker Compose (Recommended)

### Prerequisites
- Docker Desktop is running
- Docker and Docker Compose are installed

### Steps

1. **Open PowerShell/Terminal and go to the backend folder**
   ```powershell
   cd backend
   ```

2. **Start all services (detached + rebuild)**
   ```powershell
   docker-compose up -d --build
   ```

3. **Services will be available at**
   - **API**: http://localhost:8080
   - **Swagger UI**: http://localhost:8080/swagger
   - **RabbitMQ Management**: http://localhost:15672 (guest/guest by default)
   - **SQL Server**: localhost,1433 (`sa` / value from `_saPassword`)

4. **Stop services**
   ```powershell
   docker-compose down
   ```

### Required: `.env` configuration

Create a `.env` file in the `backend` folder before running compose.
Current `docker-compose.yml` uses required variable guards (`:?required`) for critical values.

```env
_rabbitMqUser=guest
_rabbitMqPassword=guest
_rabbitMqHost=rabbitmq
_rabbitMqPort=5672
_saPassword=QWEasd123!
_source=sqlserver
_catalog=220016
_stripe=sk_test_xxx
_stripePublishableKey=pk_test_xxx
_stripePublishable=pk_test_xxx
_stripeWebhookSecret=whsec_xxx
_jwtKey=dev_jwt_key_change_me_please_32_chars_min
_jwtIssuer=easypark-api
_jwtAudience=easypark-clients
_corsOrigins=http://localhost:3000,http://localhost:8080,http://localhost:54878
_connectionString=Server=sqlserver,1433;Database=220016;User Id=sa;Password=QWEasd123!;TrustServerCertificate=True;

# SMTP (required by subscriber mail worker)
_fromAddress=your-email@gmail.com
_password=your-app-password
_host=smtp.gmail.com
_enableSSL=true
_displayName=EasyPark
_timeout=255
_port=465
```

Tip: use `backend/.env.example` as base template, then fill local values.

---

## Option 2: Run locally (without Docker)

### Prerequisites
- .NET 8 SDK
- SQL Server available
- RabbitMQ available

### Steps

1. Go to backend folder:
   ```powershell
   cd backend
   ```

2. Run API project:
   ```powershell
   dotnet run --project EasyPark.API/EasyPark.API.csproj
   ```

3. In another terminal, run Subscriber:
   ```powershell
   cd EasyPark.Subscriber
   dotnet run
   ```

### Notes
- Start SQL Server and RabbitMQ first
- Ensure connection string and env vars are configured

---

## Test Users (after seed)

- **Desktop admin**: username `desktop`, password `test`
- **Mobile user**: username `mobile`, password `test`

---

## Troubleshooting

### Docker Desktop not running
Start Docker Desktop and wait until it is fully initialized.

### Unable to pull image
Check Docker status and internet connection.

### `dotnet run` can't find project
Use:
```powershell
dotnet run --project EasyPark.API/EasyPark.API.csproj
```

### Port already in use
Change port mappings in `docker-compose.yml` or stop conflicting services.

---

## Additional Documentation

- Seed data and backend test coverage: `SEED_AND_TESTS.md`

