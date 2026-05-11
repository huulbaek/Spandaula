# Authentication

Spandaula uses WebView-based authentication to handle Aula's MitID login flow and HttpOnly cookies.

## Why WebView?

Aula uses HttpOnly session cookies that cannot be accessed via JavaScript's `document.cookie`. The official Aula app has privileged OAuth access with refresh tokens, but this isn't available to third-party apps. WebView-based auth is the only viable approach.

## Authentication Flow

### Initial Login

1. `LoginScreen` displays a WebView loading `https://www.aula.dk/`
2. User authenticates via MitID (2-factor, no password to store)
3. After successful login, user is redirected to `/portal`
4. `_checkSession()` detects the portal page and validates via XHR
5. `WebviewCookieManager` extracts **all cookies including HttpOnly** via native APIs
6. Cookies are stored in Hive as structured JSON
7. Auth state changes to authenticated, main app is shown

### Session Restoration (App Restart)

1. `AuthService.init()` checks for stored cookies (doesn't validate - can't use HttpOnly with HTTP client)
2. `LoginScreen` mounts and restores cookies to WebView via `WebviewCookieManager.setCookies()`
3. WebView loads aula.dk with restored cookies
4. If session valid: user lands on portal, `_checkSession()` completes login
5. If session expired: user sees login page, `_needsManualLogin = true`

### Session Keep-Alive

- Periodic timer calls `session.keepAlive` every 5 minutes while app is active
- `lastActivity` timestamp updated on successful API calls
- On app resume from background, session is validated via `validateSession()`

## Key Components

| Component | Purpose |
|-----------|---------|
| `WebviewCookieManager` | Native cookie access (iOS httpCookieStore / Android CookieManager) |
| `SessionStorage` | Persists cookies as JSON in Hive, tracks last activity |
| `AuthService` | Manages auth state, keep-alive timer |
| `LoginScreen` | WebView host, cookie restore/extract, session detection |
| `WebViewApiClient` | Makes API calls through WebView to use HttpOnly cookies |

## Cookie Storage

Cookies are stored in two formats for compatibility:

1. **Structured JSON** (`cookies_json`): Full cookie objects including HttpOnly
   ```json
   [{"name": "session", "value": "...", "domain": ".aula.dk", "httpOnly": true, ...}]
   ```

2. **Legacy string** (`session_cookie`): `document.cookie` output (non-HttpOnly only)

## Session Timeout

- Stored sessions are considered potentially valid for **7 days**
- Actual validity is determined by API response when WebView loads
- Keep-alive calls extend the server-side session

## Limitations

- No refresh tokens (official app has privileged OAuth access)
- Session depends on Aula's server-side timeout policy
- Must re-authenticate with MitID when session truly expires
- Cannot use biometric unlock to skip MitID (no credentials to store - it's 2FA)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         App Start                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  AuthService.init() - Check for stored cookies              │
│  (Don't validate with HTTP - can't use HttpOnly cookies)    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  LoginScreen mounts (always, but offstage when auth'd)      │
│  1. Restore cookies via WebviewCookieManager                │
│  2. Load aula.dk                                            │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│  Cookies Valid           │    │  Cookies Expired         │
│  → Lands on /portal      │    │  → Lands on /login       │
│  → _checkSession()       │    │  → Show WebView          │
│  → Complete login        │    │  → User does MitID       │
└──────────────────────────┘    └──────────────────────────┘
              │                               │
              └───────────────┬───────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Authenticated State                                         │
│  - Keep-alive timer running (5 min interval)                │
│  - WebViewApiClient uses WebView for API calls              │
│  - App lifecycle observer validates on resume               │
└─────────────────────────────────────────────────────────────┘
```
