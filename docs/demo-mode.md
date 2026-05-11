# Demo Mode

Demo mode allows you to showcase the app with realistic but fake data, protecting user privacy in screencasts and presentations.

## Overview

The demo system has three phases:

1. **Record** - Capture real API responses while using the app
2. **Sanitize** - Replace real names with fake Danish names
3. **Playback** - Run the app with sanitized data (no real API calls)

## Quick Start

### Step 1: Record API Data

Run the app in recording mode:

```bash
flutter run --dart-define=RECORD_API=true
```

- A red **REC** indicator appears in the top-right corner
- Click through all screens you want to demo (wall, messages, etc.)
- Tap the green **EXPORT** button to copy data to clipboard
- Paste into a file: `demo_data_raw.json`

The data is also printed to console as base64 (in case clipboard doesn't work):
```bash
echo "BASE64_STRING" | base64 -d > demo_data_raw.json
```

### Step 2: Sanitize the Data

Run the sanitizer script:

```bash
dart run tools/sanitize_demo_data.dart demo_data_raw.json assets/demo_data.json
```

This will:
- Replace all names with fake Danish names (consistent mapping)
- Replace institution names with fake school names
- Remove profile pictures
- Print a summary of all name mappings for review

Example output:
```
=== Name Mappings ===
First names: 12
  Michelle -> Anders
  Jonas -> Anne
  ...

Institutions: 3
  Børnehuset Vores Sted -> Skovbrynet Skole
  ...
```

### Step 3: Run in Demo Mode

```bash
flutter run --dart-define=DEMO_MODE=true
```

- An orange **DEMO** indicator appears in the top-right corner
- The app uses sanitized data instead of real API calls
- Profile shows fake names: Anders Hansen with children Emma and Oliver

### Step 4: Hide Badge for Screencasts

For clean screencasts without the "DEMO" badge:

```bash
flutter run --dart-define=DEMO_MODE=true --dart-define=HIDE_DEMO_BADGE=true
```

## How It Works

### Recording (`RECORD_API=true`)

The `WebViewApiClient` intercepts all API responses and stores them in `DemoDataService`. Each API call is keyed by method name and parameters.

### Sanitization

The `tools/sanitize_demo_data.dart` script:
- Scans all JSON for name fields (`firstName`, `lastName`, `fullName`, `name`, etc.)
- Builds a consistent mapping of real → fake names
- Replaces names in all occurrences
- Does NOT modify text content (titles, message bodies) to avoid mangling

### Playback (`DEMO_MODE=true`)

The `DemoDataService` intercepts API calls and returns recorded data:
1. First tries exact key match (method + params)
2. Falls back to fuzzy matching (method name only) to handle ID differences

The login screen uses a hardcoded demo profile with fake names, bypassing real authentication.

## Files

| File | Purpose |
|------|---------|
| `lib/core/demo/demo_config.dart` | Configuration flags |
| `lib/core/demo/demo_data_service.dart` | Recording and playback logic |
| `lib/core/demo/demo_profile.dart` | Fake profile for demo mode |
| `lib/shared/widgets/demo_mode_banner.dart` | UI indicators |
| `tools/sanitize_demo_data.dart` | Name replacement script |
| `assets/demo_data.json` | Sanitized playback data |

## Tips

### Recording All Screens

Make sure to click through:
- Wall (posts feed)
- Messages (thread list)
- Individual message threads (click into at least one)
- Children screen
- Any other screens you want to demo

### Missing API Data

If you see errors in demo mode, it means that API call wasn't recorded. Re-run in recording mode and navigate to that screen.

### Updating Demo Data

To update the demo data:
1. Delete `assets/demo_data.json`
2. Run with `RECORD_API=true` and click through all screens
3. Export and sanitize again

### Customizing Fake Names

Edit the name lists in `tools/sanitize_demo_data.dart`:
- `danishFirstNames` - First name options
- `danishLastNames` - Last name options
- `fakeSchoolNames` - Institution name options

Edit `lib/core/demo/demo_profile.dart` to change the demo user's profile.

## Troubleshooting

### "No playback data for X"

The API call wasn't recorded. Re-record with that screen included.

### Names still showing in text

The sanitizer only replaces structured name fields, not names mentioned in message text. This is intentional to avoid mangling content like "VARMT" → "VANDERSMTrine".

### Wrong profile names in Children screen

The demo profile is hardcoded in `demo_profile.dart`. Edit it to match your desired demo names.
