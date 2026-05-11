import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';

/// Custom exception for Aula API errors
class AulaApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isAuthError;

  AulaApiException(this.message, {this.statusCode, this.isAuthError = false});

  @override
  String toString() => 'AulaApiException: $message (status: $statusCode)';
}

/// HTTP client for Aula API with cookie-based session management
class AulaClient {
  final http.Client _client;
  String? _sessionCookie;
  final void Function()? onAuthRequired;

  AulaClient({
    http.Client? client,
    this.onAuthRequired,
  }) : _client = client ?? http.Client();

  /// Set session cookie from WebView login
  void setSessionCookie(String cookie) {
    _sessionCookie = cookie;
  }

  /// Clear session (logout)
  void clearSession() {
    _sessionCookie = null;
  }

  /// Check if we have a session
  bool get hasSession => _sessionCookie != null && _sessionCookie!.isNotEmpty;

  /// Get request headers with session cookie and CSRF token
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;

      // Extract CSRF token from cookies (Csrfp-Token cookie)
      final csrfToken = _extractCsrfToken(_sessionCookie!);
      if (csrfToken != null) {
        headers['csrfp-token'] = csrfToken;
      }
    }
    return headers;
  }

  /// Extract CSRF token from cookie string
  String? _extractCsrfToken(String cookies) {
    // Look for Csrfp-Token cookie (case insensitive)
    final cookieParts = cookies.split(';');
    for (final part in cookieParts) {
      final trimmed = part.trim();
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('csrfp-token=')) {
        return trimmed.substring('csrfp-token='.length);
      }
    }
    return null;
  }

  /// Build URL with method parameter
  Uri _buildUrl(String method, [Map<String, dynamic>? queryParams]) {
    final params = <String, String>{'method': method};
    if (queryParams != null) {
      queryParams.forEach((key, value) {
        if (value is List) {
          // Handle array params like institutionProfileIds[]
          for (int i = 0; i < value.length; i++) {
            params['$key[$i]'] = value[i].toString();
          }
        } else if (value != null) {
          params[key] = value.toString();
        }
      });
    }
    return Uri.parse(ApiEndpoints.baseUrl).replace(queryParameters: params);
  }

  /// Handle API response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.body.contains('"status":"error"') &&
            response.body.contains('login')) {
      onAuthRequired?.call();
      throw AulaApiException(
        'Authentication required',
        statusCode: response.statusCode,
        isAuthError: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AulaApiException(
        'Request failed',
        statusCode: response.statusCode,
      );
    }

    try {
      final json = jsonDecode(response.body);
      if (json is Map && json['status'] == 'error') {
        throw AulaApiException(
          json['message'] ?? 'Unknown error',
          statusCode: response.statusCode,
        );
      }
      // Aula wraps responses in a data field
      return json['data'] ?? json;
    } catch (e) {
      if (e is AulaApiException) rethrow;
      throw AulaApiException('Failed to parse response: $e');
    }
  }

  /// GET request
  Future<dynamic> get(
    String method, {
    Map<String, dynamic>? queryParams,
  }) async {
    final url = _buildUrl(method, queryParams);
    final response = await _client.get(url, headers: _headers);
    return _handleResponse(response);
  }

  /// POST request
  Future<dynamic> post(
    String method, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    final url = _buildUrl(method, queryParams);
    final response = await _client.post(
      url,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Keep session alive
  Future<void> keepAlive() async {
    await get(ApiEndpoints.keepAlive);
  }

  void dispose() {
    _client.close();
  }
}
