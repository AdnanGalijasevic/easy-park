# EasyPark

EasyPark consists of:

- `backend` (.NET API + Subscriber + SQL Server + RabbitMQ)
- `frontend/easypark_desktop` (Flutter desktop admin app)
- `frontend/easypark_mobile` (Flutter mobile client app)

Project topic proposal is available in `RSII_IB220016.docx`.

## 1) Run backend (RSII-ready)

Prerequisites:

- Docker Desktop

From `backend` folder:

```powershell
docker-compose up -d --build
```

Main URLs:

- API: `http://localhost:8080`
- Swagger: `http://localhost:8080/swagger`
- RabbitMQ UI: `http://localhost:15672`

Stop:

```powershell
docker-compose down
```

## 2) Run desktop app

From `frontend/easypark_desktop`:

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE=http://localhost:8080/
```

## 3) Run mobile app

From `frontend/easypark_mobile`:

```powershell
flutter pub get
flutter run --dart-define=API_BASE=http://10.0.2.2:8080
```

For physical device, replace `API_BASE` with your machine IP.

## 4) Test credentials

| Context         | Username | Password |
| --------------- | -------- | -------- |
| Desktop (admin) | desktop  | test     |
| Mobile (user)   | mobile   | test     |

## 5) Secret env files

- Backend env archive location: `backend/.env.7p`
- Unzip this archive into: `backend/.env`
- Mobile env archive location: `frontend/easypark_mobile/.env.7p`
- Unzip this archive into: `frontend/easypark_mobile/.env`

If you build the mobile app again, update values in:

- `frontend/easypark_mobile/.env`
