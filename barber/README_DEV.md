# Barber Club - Development Guide

## Prerequisites

- Flutter SDK 3.10.7 or higher
- Dart SDK 3.10.7 or higher
- Backend API running (see `../backend/README.md`)

## Installation

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Generate code files (freezed, json_serializable):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## API Base URL Configuration

The app uses `--dart-define` to configure the API base URL.

### Android Emulator (default)

The default URL is `http://10.0.2.2:3000` (which maps to `localhost:3000` on your host machine).

```bash
flutter run
```

or explicitly:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

### iOS Simulator

For iOS Simulator, use `http://localhost:3000` or your machine's IP on the local network:

```bash
# Option 1: localhost (if backend on same machine)
flutter run --dart-define=API_BASE_URL=http://localhost:3000

# Option 2: Local IP (if backend on network)
flutter run --dart-define=API_BASE_URL=http://192.168.1.XXX:3000
```

### Physical Device

For a physical device (Android or iOS), use your machine's IP on the local network:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.XXX:3000
```

**Note:** Replace `192.168.1.XXX` with your machine's actual IP. You can find it with:
- Windows: `ipconfig`
- macOS/Linux: `ifconfig` or `ip addr`

## Running

### Development mode

```bash
flutter run
```

### Release mode

```bash
flutter run --release
```

## Tests

Run unit tests:

```bash
flutter test
```

Tests cover:
- Form validation (email, phone, password)
- Validators with localized error messages

## Project Structure

```
lib/
├── core/
│   ├── config/          # Configuration (API base URL)
│   ├── network/         # Dio client with interceptors
│   ├── storage/         # Token repository (secure storage)
│   └── validators/      # Form validators
├── domain/
│   ├── models/          # Domain models (User, AuthResponse, etc.)
│   └── repositories/    # Repository interfaces
├── data/
│   └── repositories/    # Repository implementations
└── presentation/
    ├── providers/       # Riverpod providers
    ├── screens/         # UI screens
    ├── routing/         # GoRouter configuration
    └── theme/           # Material 3 theme
```

## Implemented Features

### Authentication

- ✅ Login (email or phone + password)
- ✅ Sign up (name, email, phone, password)
- ✅ Forgot password
- ✅ Session handling (bootstrap on startup)
- ✅ Logout
- ✅ Automatic refresh token
- ✅ Secure token storage

### Security

- ✅ Tokens stored in `flutter_secure_storage`
- ✅ Automatic refresh token with queue lock
- ✅ 401 error handling with redirect to login
- ✅ Client-side validation before API calls

### UI/UX

- ✅ Dark Material 3 theme (gold/beige)
- ✅ Localized error messages
- ✅ Real-time validation
- ✅ Loading states
- ✅ Navigation with GoRouter
- ✅ Accessibility (SafeArea, text scaling)

## Troubleshooting

### Network connection error

- Ensure the backend is running
- Check the API base URL with `--dart-define`
- For Android Emulator: use `http://10.0.2.2:3000`
- For iOS Simulator: use `http://localhost:3000` or local IP

### Build errors (freezed/json_serializable)

If generated files are missing:

```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Lint errors

The project uses strict lint rules. To see errors:

```bash
flutter analyze
```

## Next Steps

This implementation covers the authentication module only. The following modules will be added separately:

- Booking
- User profile
- Main navigation (tabs)
- TIMIFY integration (if needed)
