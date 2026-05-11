import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api/aula_client.dart';
import '../../core/api/webview_api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/session_storage.dart';
import '../../core/cache/cache_service.dart';
import '../../core/models/profile.dart';

/// Session storage provider
final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage();
});

/// Cache service provider
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Global AulaClient provider (no cycle - doesn't reference authService)
final aulaClientProvider = Provider<AulaClient>((ref) {
  final client = AulaClient();
  ref.onDispose(() => client.dispose());
  return client;
});

/// WebView API client that uses the WebView's session for authenticated requests
final webViewApiClientProvider = Provider<WebViewApiClient>((ref) {
  return WebViewApiClient();
});

/// Provider to set the WebView controller on the API client
void setWebViewController(WidgetRef ref, WebViewController controller) {
  ref.read(webViewApiClientProvider).setController(controller);
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(aulaClientProvider);
  final storage = ref.watch(sessionStorageProvider);
  final service = AuthService(client: client, storage: storage);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Auth state provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current profile provider
final currentProfileProvider = Provider<Profile?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentProfile;
});

/// Institution profile IDs provider
final institutionProfileIdsProvider = Provider<List<int>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.institutionProfileIds;
});

/// Institution codes provider
final institutionCodesProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(currentProfileProvider);
  return profile?.institutionCodes ?? [];
});

/// Auth notifier for handling login/logout actions
class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final AuthService _authService;
  final CacheService _cacheService;

  AuthNotifier(this._authService, this._cacheService)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _cacheService.init();
      await _authService.init();
      state = AsyncValue.data(_authService.currentState);
    } catch (e) {
      // On any init error, fall back to unauthenticated (show login)
      debugPrint('Auth init error: $e');
      state = const AsyncValue.data(AuthState.unauthenticated);
    }
  }

  /// Attempt login with cookies from WebView
  /// Throws on failure so the login screen can handle it
  Future<void> onLoginSuccess(String cookies) async {
    // Don't set to loading - that would rebuild the login screen and reset the WebView
    try {
      await _authService.onLoginSuccess(cookies);
      // Only update state on success
      state = AsyncValue.data(_authService.currentState);
    } catch (e) {
      // On login error, stay unauthenticated but rethrow for login screen
      debugPrint('Login error: $e');
      // Don't update state - keep showing login screen
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    await _cacheService.clearAll();
    state = const AsyncValue.data(AuthState.unauthenticated);
  }

  Future<void> refreshProfile() async {
    await _authService.refreshProfile();
  }

  /// Complete login with profile data already fetched from WebView
  Future<void> completeLogin(dynamic profileData) async {
    try {
      await _authService.completeLoginWithProfile(profileData);
      state = AsyncValue.data(_authService.currentState);
    } catch (e) {
      debugPrint('Complete login error: $e');
      state = const AsyncValue.data(AuthState.unauthenticated);
      rethrow;
    }
  }
}

/// Auth notifier provider
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return AuthNotifier(authService, cacheService);
});
