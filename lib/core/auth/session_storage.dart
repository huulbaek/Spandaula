import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';

/// Secure storage for session data using Hive
class SessionStorage {
  static const String _boxName = 'session';
  static const String _cookieKey = 'session_cookie';
  static const String _cookiesJsonKey = 'cookies_json';
  static const String _profileIdKey = 'profile_id';
  static const String _institutionProfileIdsKey = 'institution_profile_ids';
  static const String _lastLoginKey = 'last_login';
  static const String _lastActivityKey = 'last_activity';

  /// Session timeout - 7 days max, but we validate with API on restore
  static const int sessionTimeoutDays = 7;

  Box? _box;

  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  Future<void> saveSessionCookie(String cookie) async {
    await init();
    await _box!.put(_cookieKey, cookie);
    final now = DateTime.now().toIso8601String();
    await _box!.put(_lastLoginKey, now);
    await _box!.put(_lastActivityKey, now);
  }

  Future<String?> getSessionCookie() async {
    await init();
    return _box!.get(_cookieKey);
  }

  /// Save cookies as structured JSON (includes HttpOnly cookies)
  Future<void> saveCookies(List<Cookie> cookies) async {
    await init();
    final cookiesJson = cookies.map((c) => {
      'name': c.name,
      'value': c.value,
      'domain': c.domain,
      'path': c.path,
      'expires': c.expires?.toIso8601String(),
      'httpOnly': c.httpOnly,
      'secure': c.secure,
    }).toList();
    await _box!.put(_cookiesJsonKey, jsonEncode(cookiesJson));
    final now = DateTime.now().toIso8601String();
    await _box!.put(_lastLoginKey, now);
    await _box!.put(_lastActivityKey, now);
  }

  /// Get stored cookies as Cookie objects
  Future<List<Cookie>> getCookies() async {
    await init();
    final json = _box!.get(_cookiesJsonKey);
    if (json == null) return [];

    try {
      final List<dynamic> cookiesJson = jsonDecode(json);
      return cookiesJson.map((c) {
        final cookie = Cookie(c['name'], c['value']);
        if (c['domain'] != null) cookie.domain = c['domain'];
        if (c['path'] != null) cookie.path = c['path'];
        if (c['expires'] != null) {
          cookie.expires = DateTime.tryParse(c['expires']);
        }
        if (c['httpOnly'] != null) cookie.httpOnly = c['httpOnly'];
        if (c['secure'] != null) cookie.secure = c['secure'];
        return cookie;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if we have stored cookies
  Future<bool> hasCookies() async {
    await init();
    final json = _box!.get(_cookiesJsonKey);
    return json != null && json.isNotEmpty;
  }

  Future<void> saveProfileId(int profileId) async {
    await init();
    await _box!.put(_profileIdKey, profileId);
  }

  Future<int?> getProfileId() async {
    await init();
    return _box!.get(_profileIdKey);
  }

  Future<void> saveInstitutionProfileIds(List<int> ids) async {
    await init();
    await _box!.put(_institutionProfileIdsKey, ids);
  }

  Future<List<int>> getInstitutionProfileIds() async {
    await init();
    final ids = _box!.get(_institutionProfileIdsKey);
    if (ids == null) return [];
    return List<int>.from(ids);
  }

  Future<DateTime?> getLastLoginTime() async {
    await init();
    final dateStr = _box!.get(_lastLoginKey);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  Future<DateTime?> getLastActivityTime() async {
    await init();
    final dateStr = _box!.get(_lastActivityKey);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Update last activity timestamp (called on successful API calls)
  Future<void> updateLastActivity() async {
    await init();
    await _box!.put(_lastActivityKey, DateTime.now().toIso8601String());
  }

  /// Check if session might still be valid based on last activity
  /// Returns true if we should attempt to restore - actual validity is
  /// determined by API call success
  Future<bool> hasValidSession() async {
    // Check if we have stored cookies (preferred) or legacy cookie string
    final hasStoredCookies = await hasCookies();
    final cookie = await getSessionCookie();

    if (!hasStoredCookies && (cookie == null || cookie.isEmpty)) {
      return false;
    }

    // Check last activity time (more accurate than login time)
    final lastActivity = await getLastActivityTime();
    final lastLogin = await getLastLoginTime();
    final referenceTime = lastActivity ?? lastLogin;

    if (referenceTime == null) return false;

    // Allow sessions up to 7 days old - we'll validate with API on restore
    final sessionAge = DateTime.now().difference(referenceTime);
    return sessionAge.inDays < sessionTimeoutDays;
  }

  Future<void> clearSession() async {
    await init();
    await _box!.delete(_cookieKey);
    await _box!.delete(_cookiesJsonKey);
    await _box!.delete(_profileIdKey);
    await _box!.delete(_institutionProfileIdsKey);
    await _box!.delete(_lastLoginKey);
    await _box!.delete(_lastActivityKey);
  }

  Future<void> close() async {
    await _box?.close();
  }
}
