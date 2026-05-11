# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spandaula is a Flutter mobile app that provides an alternative client for Aula (Danish school communication platform). It uses WebView-based authentication to handle Aula's login flow and then makes API calls through the WebView to leverage HttpOnly cookies.

## Build Commands

```bash
# Get dependencies
flutter pub get

# Run code generation (Riverpod generators)
dart run build_runner build

# Run on device/simulator
flutter run

# Build for release
flutter build apk --release    # Android
flutter build ios --release    # iOS

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Architecture

### Authentication Flow
The app uses a unique WebView-based authentication approach:
1. `LoginScreen` embeds a WebView that loads Aula's login page
2. After user logs in via MitID/WAYF, cookies are captured
3. `WebViewApiClient` makes API calls through the same WebView to use HttpOnly session cookies
4. `AuthGate` in `main.dart` keeps the LoginScreen's WebView offstage (but mounted) to maintain the session

### State Management
- **Riverpod** for dependency injection and state management
- Providers defined in `lib/features/*/` feature directories
- Core providers in `lib/features/auth/auth_provider.dart`

### API Layer
- `WebViewApiClient` (`lib/core/api/webview_api_client.dart`) - Primary client that executes XHR requests through WebView JavaScript
- `AulaClient` (`lib/core/api/aula_client.dart`) - HTTP client with cookie support (less used due to HttpOnly cookie limitations)
- `ApiEndpoints` (`lib/core/api/api_endpoints.dart`) - API method constants for `https://www.aula.dk/api/v22/`

### Project Structure
```
lib/
├── core/
│   ├── api/         # API clients and endpoints
│   ├── auth/        # Auth service and session storage
│   ├── cache/       # Hive caching (currently no-op)
│   └── models/      # Data models (Profile, Post, Thread, Message)
├── features/
│   ├── auth/        # Login screen and auth providers
│   ├── messages/    # Messaging screens (threads, compose, search)
│   └── wall/        # Wall/posts feed
└── shared/
    ├── utils/       # Date formatting, HTML utilities
    └── widgets/     # Reusable widgets
```

### Key Implementation Details
- Danish locale used throughout (`da_DK` date formatting)
- UI text is in Danish
- Caching via Hive is stubbed out (no-op) pending Hive adapter generation
- CSRF token extracted from cookies for API requests
