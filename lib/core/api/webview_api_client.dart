import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_endpoints.dart';
import 'aula_client.dart';
import '../demo/demo_config.dart';
import '../demo/demo_data_service.dart';

/// API client that makes requests through a WebView to use HttpOnly cookies
class WebViewApiClient {
  WebViewController? _controller;
  final void Function()? onAuthRequired;
  final DemoDataService _demoService = DemoDataService.instance;

  WebViewApiClient({this.onAuthRequired});

  /// Set the WebView controller to use for requests
  void setController(WebViewController controller) {
    _controller = controller;
  }

  /// Check if we have a controller
  bool get hasController => _controller != null;

  /// Make a GET request through the WebView
  Future<dynamic> get(
    String method, {
    Map<String, dynamic>? queryParams,
  }) async {
    // In demo mode, try to get playback data first
    if (DemoConfig.demoMode) {
      final playback = _demoService.getPlayback(method, queryParams);
      if (playback != null) {
        return playback;
      }
    }

    final url = _buildUrl(method, queryParams);
    final response = await _makeRequest('GET', url);

    // Record response if in recording mode
    if (DemoConfig.recordApi) {
      await _demoService.record(method, queryParams, response);
    }

    return response;
  }

  /// Make a POST request through the WebView
  Future<dynamic> post(
    String method, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    // In demo mode, try to get playback data first
    if (DemoConfig.demoMode) {
      final playback = _demoService.getPlayback(method, queryParams);
      if (playback != null) {
        return playback;
      }
    }

    final url = _buildUrl(method, queryParams);
    final response = await _makeRequest('POST', url, body: body);

    // Record response if in recording mode
    if (DemoConfig.recordApi) {
      await _demoService.record(method, queryParams, response);
    }

    return response;
  }

  String _buildUrl(String method, [Map<String, dynamic>? queryParams]) {
    // Build query string manually to support repeated keys for arrays (key[]=value&key[]=value)
    final parts = <String>['method=$method'];
    if (queryParams != null) {
      queryParams.forEach((key, value) {
        if (value is List) {
          // Aula expects key[]=value&key[]=value format for arrays
          for (final item in value) {
            parts.add('${Uri.encodeQueryComponent('$key[]')}=${Uri.encodeQueryComponent(item.toString())}');
          }
        } else if (value != null) {
          parts.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value.toString())}');
        }
      });
    }
    return '${ApiEndpoints.baseUrl}?${parts.join('&')}';
  }

  Future<dynamic> _makeRequest(String httpMethod, String url, {Map<String, dynamic>? body}) async {
    if (_controller == null) {
      throw AulaApiException('WebView controller not set', isAuthError: true);
    }

    final bodyJson = body != null ? jsonEncode(body).replaceAll("'", "\\'") : 'null';

    final js = '''
      (function() {
        var xhr = new XMLHttpRequest();
        xhr.open('$httpMethod', '$url', false);
        xhr.withCredentials = true;
        xhr.setRequestHeader('Accept', 'application/json');
        xhr.setRequestHeader('Content-Type', 'application/json');
        try {
          ${httpMethod == 'POST' ? "xhr.send('$bodyJson');" : "xhr.send();"}
          return JSON.stringify({
            status: xhr.status,
            response: xhr.responseText
          });
        } catch(e) {
          return JSON.stringify({
            status: 0,
            error: e.toString()
          });
        }
      })()
    ''';

    final result = await _controller!.runJavaScriptReturningResult(js);

    String resultStr = result.toString();
    // Remove surrounding quotes if present
    if (resultStr.startsWith('"') && resultStr.endsWith('"')) {
      resultStr = resultStr.substring(1, resultStr.length - 1);
      resultStr = resultStr
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\n', '\n')
          .replaceAll(r'\\', r'\');
    }

    final responseData = jsonDecode(resultStr);
    final status = responseData['status'] as int;
    final responseText = responseData['response'] as String? ?? '';

    debugPrint('WebViewApiClient: $httpMethod $url -> status $status');

    if (status == 401 || status == 403) {
      onAuthRequired?.call();
      throw AulaApiException(
        'Authentication required',
        statusCode: status,
        isAuthError: true,
      );
    }

    if (status < 200 || status >= 300) {
      throw AulaApiException(
        'Request failed: ${responseData['error'] ?? responseText}',
        statusCode: status,
      );
    }

    try {
      final json = jsonDecode(responseText);
      if (json is Map && json['status'] == 'error') {
        throw AulaApiException(
          json['message'] ?? 'Unknown error',
          statusCode: status,
        );
      }
      return json['data'] ?? json;
    } catch (e) {
      if (e is AulaApiException) rethrow;
      throw AulaApiException('Failed to parse response: $e');
    }
  }

  /// Keep session alive
  Future<void> keepAlive() async {
    await get(ApiEndpoints.keepAlive);
  }
}
