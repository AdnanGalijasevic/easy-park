# EasyPark Mobile

Flutter mobile client for EasyPark.

## Prerequisites

- Flutter SDK (see `flutter --version`)
- Running EasyPark backend API (default `http://localhost:8080`)

## Configuration

The app resolves API URL in this order:

1. `--dart-define=API_BASE=...`
2. `.env` / `assets/config.env` (`API_BASE=...`)
3. Platform defaults:
   - Android emulator: `http://10.0.2.2:8080`
   - Web: `http://127.0.0.1:8080`
   - Other platforms: `http://localhost:8080`

Optional Stripe key in `.env` or `assets/config.env`:

- `STRIPE_PUBLISHABLE_KEY=...`
- `GOOGLE_MAPS_API_KEY=...` (required for map tiles/places features)

Example `assets/config.env`:

```env
API_BASE=http://192.168.1.5:8080
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
GOOGLE_MAPS_API_KEY=your_google_maps_key
```

## Install dependencies

```powershell
flutter pub get
```

## Run

Android emulator:

```powershell
flutter run --dart-define=API_BASE=http://10.0.2.2:8080
```

Physical device (replace with your machine LAN IP):

```powershell
flutter run --dart-define=API_BASE=http://192.168.1.5:8080
```

Chrome/web:

```powershell
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8080
```

## Notes

- If backend runs in Docker, keep API port `8080` exposed.
- Deep-link payment return handling is wired in `lib/main.dart`.
