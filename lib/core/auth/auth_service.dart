import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/aula_client.dart';
import '../api/api_endpoints.dart';
import '../models/profile.dart';
import 'session_storage.dart';

/// Authentication state
enum AuthState {
  unknown,
  authenticated,
  unauthenticated,
}

/// Service to manage authentication flow and session
class AuthService {
  final AulaClient _client;
  final SessionStorage _storage;

  Profile? _currentProfile;
  List<int> _institutionProfileIds = [];
  AuthState _state = AuthState.unknown;

  Timer? _keepAliveTimer;
  static const Duration _keepAliveInterval = Duration(minutes: 5);

  final _authStateController = StreamController<AuthState>.broadcast();

  AuthService({
    required AulaClient client,
    required SessionStorage storage,
  })  : _client = client,
        _storage = storage;

  Stream<AuthState> get authStateChanges => _authStateController.stream;
  AuthState get currentState => _state;
  Profile? get currentProfile => _currentProfile;
  List<int> get institutionProfileIds => _institutionProfileIds;

  /// Initialize auth state from stored session
  /// Note: We don't validate here because HttpOnly cookies can only be used
  /// by the WebView. Let LoginScreen restore cookies and validate via WebView.
  Future<void> init() async {
    final hasSession = await _storage.hasValidSession();
    if (hasSession) {
      // We have potentially valid cookies stored
      // Don't try to validate with HTTP client - it doesn't have HttpOnly cookies
      // Let LoginScreen restore cookies to WebView and validate
      debugPrint('Found stored session - LoginScreen will validate via WebView');

      // Pre-load institution profile IDs for when session is validated
      _institutionProfileIds = await _storage.getInstitutionProfileIds();

      // Set non-HttpOnly cookies on HTTP client (for fallback use)
      final cookie = await _storage.getSessionCookie();
      if (cookie != null) {
        _client.setSessionCookie(cookie);
      }
    }
    // Always start unauthenticated - LoginScreen will validate and authenticate
    _updateState(AuthState.unauthenticated);
  }

  /// Handle successful WebView login
  Future<void> onLoginSuccess(String cookies) async {
    _client.setSessionCookie(cookies);
    await _storage.saveSessionCookie(cookies);

    // Fetch profile and institution data
    await _fetchProfile();
    _updateState(AuthState.authenticated);
    _startKeepAliveTimer();
  }

  /// Fetch current user profile
  Future<void> _fetchProfile() async {
    final data = await _client.get(ApiEndpoints.getProfilesByLogin);

    if (data is List && data.isNotEmpty) {
      _currentProfile = Profile.fromJson(data[0]);

      // Extract all institution profile IDs
      _institutionProfileIds = [];
      for (final profileData in data) {
        final institutionProfiles =
            profileData['institutionProfiles'] as List? ?? [];
        for (final ip in institutionProfiles) {
          final id = ip['id'] as int?;
          if (id != null && !_institutionProfileIds.contains(id)) {
            _institutionProfileIds.add(id);
          }
        }
      }

      // Also add children's institution profile IDs
      for (final child in _currentProfile!.children) {
        if (child.institutionProfileId != null &&
            !_institutionProfileIds.contains(child.institutionProfileId)) {
          _institutionProfileIds.add(child.institutionProfileId!);
        }
      }

      await _storage.saveProfileId(_currentProfile!.id);
      await _storage.saveInstitutionProfileIds(_institutionProfileIds);
    }
  }

  /// Refresh profile data
  Future<Profile?> refreshProfile() async {
    await _fetchProfile();
    return _currentProfile;
  }

  /// Complete login with profile data already fetched (from WebView)
  Future<void> completeLoginWithProfile(dynamic profileData) async {
    // Handle both formats:
    // - List directly: [{...profile...}]
    // - Map with profiles key: {"profiles": [{...profile...}]}
    List? profiles;
    if (profileData is List) {
      profiles = profileData;
    } else if (profileData is Map && profileData['profiles'] is List) {
      profiles = profileData['profiles'] as List;
    }

    if (profiles != null && profiles.isNotEmpty) {
      _currentProfile = Profile.fromJson(profiles[0]);

      // Extract all institution profile IDs
      _institutionProfileIds = [];
      for (final pd in profiles) {
        final institutionProfiles = pd['institutionProfiles'] as List? ?? [];
        for (final ip in institutionProfiles) {
          final id = ip['id'] as int?;
          if (id != null && !_institutionProfileIds.contains(id)) {
            _institutionProfileIds.add(id);
          }
        }
      }

      // Also add children's institution profile IDs
      for (final child in _currentProfile!.children) {
        if (child.institutionProfileId != null &&
            !_institutionProfileIds.contains(child.institutionProfileId)) {
          _institutionProfileIds.add(child.institutionProfileId!);
        }
      }

      await _storage.saveProfileId(_currentProfile!.id);
      await _storage.saveInstitutionProfileIds(_institutionProfileIds);
      _updateState(AuthState.authenticated);
      _startKeepAliveTimer();
    } else {
      throw Exception('Invalid profile data');
    }
  }

  /// Logout
  Future<void> logout() async {
    _stopKeepAliveTimer();
    _client.clearSession();
    await _storage.clearSession();
    _currentProfile = null;
    _institutionProfileIds = [];
    _updateState(AuthState.unauthenticated);
  }

  /// Keep session alive - called periodically and on app resume
  Future<bool> keepAlive() async {
    if (_state == AuthState.authenticated) {
      try {
        await _client.keepAlive();
        await _storage.updateLastActivity();
        debugPrint('Keep-alive successful');
        return true;
      } catch (e) {
        debugPrint('Keep-alive failed: $e');
        // Session might have expired
        if (e is AulaApiException && e.isAuthError) {
          _stopKeepAliveTimer();
          _updateState(AuthState.unauthenticated);
        }
        return false;
      }
    }
    return false;
  }

  /// Start periodic keep-alive timer
  void _startKeepAliveTimer() {
    _stopKeepAliveTimer();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) {
      keepAlive();
    });
    debugPrint('Keep-alive timer started (interval: $_keepAliveInterval)');
  }

  /// Stop keep-alive timer
  void _stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Validate session on app resume
  Future<bool> validateSession() async {
    if (_state != AuthState.authenticated) return false;
    return await keepAlive();
  }

  void _updateState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      _authStateController.add(newState);
    }
  }

  void dispose() {
    _stopKeepAliveTimer();
    _authStateController.close();
  }
}
