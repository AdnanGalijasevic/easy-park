# EasyPark Desktop Application

Flutter desktop admin application for EasyPark parking management system.

## Structure

```
lib/
├── main.dart                    # Application entry point
├── app_colors.dart              # Color definitions
├── models/                      # Data models
│   ├── parking_location_model.dart
│   ├── parking_spot_model.dart
│   ├── user_model.dart
│   └── reservation_history_model.dart
├── providers/                   # API providers
│   ├── base_provider.dart
│   ├── auth_provider.dart
│   ├── parking_location_provider.dart
│   ├── parking_spot_provider.dart
│   └── reservation_history_provider.dart
├── screens/                     # Application screens
│   ├── master_screen.dart
│   ├── parking_locations_screen.dart
│   ├── parking_spots_screen.dart
│   └── reservation_history_screen.dart
├── widgets/                     # Reusable widgets
│   ├── pagination_controls.dart
│   ├── map_picker.dart
│   └── bulk_spot_creator.dart
└── utils/                       # Utility functions
    └── utils.dart
```

## Features

- **Parking Locations Management**: Full CRUD operations with map-based location selection
- **Reservation History**: View logs of all reservation status changes
- **Reports and Dashboard**: Monthly reporting, dashboard metrics, and PDF export paths
- **Authentication and Account Flows**: Login/logout, forgot/reset password, and profile/password update screens

## Running the Application

### Prerequisites

- Flutter SDK (latest stable version)
- Backend API running on `http://localhost:8080`

### Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Generate model files (if using json_serializable):
```bash
flutter pub run build_runner build
```

3. Run the application:
```bash
flutter run -d windows
```

Or specify a different base URL:
```bash
flutter run -d windows --dart-define=API_BASE=http://localhost:8080/
```

## Default Credentials

- **Username**: `desktop`
- **Password**: `test`

## Configuration

The API base URL can be configured via:
- Environment variable: `API_BASE` (default: `http://localhost:8080/`)
- Command line: `--dart-define=API_BASE=<your-url>`

## Code Style

- Follows the same structure and conventions as the TripTicket desktop application
- No comments in code
- Consistent naming and formatting
- Proper error handling with user-friendly messages

