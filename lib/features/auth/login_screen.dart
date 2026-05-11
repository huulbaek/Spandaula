import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/demo/demo_config.dart';
import '../../core/demo/demo_profile.dart';
import '../../shared/widgets/app_spinner.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  final WebviewCookieManager _cookieManager = WebviewCookieManager();
  bool _isLoading = true;
  bool _needsManualLogin = false;
  String? _error;
  bool _loginInProgress = false;
  bool _loginComplete = false;

  static const String _aulaUrl = 'https://www.aula.dk/';
  static const String _profileApiUrl =
      'https://www.aula.dk/api/v23/?method=profiles.getProfilesByLogin';

  @override
  void initState() {
    super.initState();
    _initWebView();

    // In demo mode, trigger login immediately
    if (DemoConfig.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkSession();
      });
    }
  }

  Future<void> _restoreCookiesAndLoad() async {
    // Restore cookies BEFORE loading the URL
    try {
      final storage = ref.read(sessionStorageProvider);
      final cookies = await storage.getCookies();

      if (cookies.isNotEmpty) {
        debugPrint('Restoring ${cookies.length} cookies to WebView...');
        for (final cookie in cookies) {
          await _cookieManager.setCookies([cookie]);
        }
        debugPrint('Cookies restored successfully');
      }
    } catch (e) {
      debugPrint('Failed to restore cookies: $e');
    }

    // Now load the URL (cookies are already set)
    await _controller.loadRequest(Uri.parse(_aulaUrl));
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() => _isLoading = false);
            }

            // Check if this is a login page - user needs to manually login
            if (_isLoginPage(url)) {
              if (mounted) {
                setState(() => _needsManualLogin = true);
              }
              return;
            }

            // Check for session on any aula.dk page that's not a login page
            // (after MitID login, URL may be /, /portal, or hash-routed)
            if (url.contains('aula.dk') && !_loginInProgress) {
              await _checkSession();
              return;
            }

            // Fallback: non-aula.dk page — show the WebView so the user can
            // interact (e.g. redirect to an auth provider)
            if (mounted && !_loginInProgress) {
              setState(() => _needsManualLogin = true);
            }
          },
          onWebResourceError: (error) {
            if (error.errorType == WebResourceErrorType.connect ||
                error.errorType == WebResourceErrorType.hostLookup) {
              if (mounted) {
                setState(() {
                  _error = 'Ingen internetforbindelse';
                  _isLoading = false;
                });
              }
            }
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    // Restore cookies first, then load URL
    _restoreCookiesAndLoad();
  }

  bool _isLoginPage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('login') ||
        lower.contains('logon') ||
        lower.contains('signin') ||
        lower.contains('authenticate') ||
        lower.contains('mitid') ||
        lower.contains('nemlog');
  }

  /// Check if logged in by detecting logged-in page state
  Future<void> _checkSession() async {
    if (_loginInProgress) return;

    // In demo mode, use fake profile data with a brief loading delay
    if (DemoConfig.demoMode) {
      debugPrint('Login screen: Demo mode - using fake profile');
      _loginInProgress = true;
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await _loginWithProfile(demoProfileData, 'demo_session=true');
      return;
    }

    try {
      final currentUrl = await _controller.currentUrl();
      debugPrint('Login screen: Current URL: $currentUrl');

      // If we're on aula.dk (not a login page), try to get profile via XHR
      if (currentUrl != null &&
          currentUrl.contains('aula.dk') &&
          !_isLoginPage(currentUrl)) {

        // First, log what cookies we have
        final cookiesResult = await _controller.runJavaScriptReturningResult('document.cookie');
        debugPrint('Login screen: document.cookie = $cookiesResult');

        // Use synchronous XHR to fetch profile
        final profileResult = await _controller.runJavaScriptReturningResult('''
          (function() {
            var xhr = new XMLHttpRequest();
            xhr.open('GET', '$_profileApiUrl', false);
            xhr.withCredentials = true;
            xhr.setRequestHeader('Accept', 'application/json, text/plain, */*');
            try {
              xhr.send();
              if (xhr.status === 200) {
                return xhr.responseText;
              }
              return '{"error": "status ' + xhr.status + '"}';
            } catch(e) {
              return '{"error": "' + e.toString() + '"}';
            }
          })()
        ''');

        String resultStr = profileResult.toString();
        // Remove surrounding quotes if present
        if (resultStr.startsWith('"') && resultStr.endsWith('"')) {
          resultStr = resultStr.substring(1, resultStr.length - 1);
          // Unescape
          resultStr = resultStr
              .replaceAll(r'\"', '"')
              .replaceAll(r'\\n', '\n')
              .replaceAll(r'\\', r'\');
        }

        debugPrint('Login screen: Profile API response length: ${resultStr.length}');
        debugPrint('Login screen: Profile API response: $resultStr');

        // Check for auth/API errors - show login WebView if session is invalid
        if (resultStr.contains('"error"')) {
          debugPrint('Login screen: API error, showing login: $resultStr');
          if (mounted) {
            setState(() => _needsManualLogin = true);
          }
          return;
        }

        try {
          final json = jsonDecode(resultStr);
          final data = json['data'];
          debugPrint('Login screen: data type: ${data.runtimeType}');

          // Extract profiles from various response formats:
          // getProfilesByLogin: data is List of profiles
          // getProfileContext: data is Map with 'profiles' key or profile fields directly
          List? profiles;
          if (data is List) {
            profiles = data;
          } else if (data is Map) {
            if (data['profiles'] is List) {
              profiles = data['profiles'] as List;
            } else if (data.containsKey('id') || data.containsKey('profileId')) {
              // Single profile object - wrap in list
              profiles = [data];
            }
          }

          if (profiles != null && profiles.isNotEmpty) {
            debugPrint('Login screen: Got ${profiles.length} profiles, logging in...');
            _loginInProgress = true;

            final cookies = await _getCookies();
            await _loginWithProfile(data, cookies);
            return;
          } else {
            debugPrint('Login screen: No profiles found in response. Data keys: ${data is Map ? data.keys.toList() : 'N/A'}');
          }
        } catch (e) {
          debugPrint('Login screen: JSON parse error: $e');
        }
      }
    } catch (e) {
      debugPrint('Login screen: Session check error: $e');
    }
  }

  /// Get cookies from document.cookie
  Future<String> _getCookies() async {
    final cookiesResult = await _controller.runJavaScriptReturningResult('document.cookie');
    String cookies = cookiesResult.toString();
    if (cookies.startsWith('"') && cookies.endsWith('"')) {
      cookies = cookies.substring(1, cookies.length - 1);
    }
    return cookies;
  }

  Future<void> _loginWithProfile(dynamic profileData, String documentCookies) async {
    // Get ALL cookies including HttpOnly using native cookie manager
    try {
      final allCookies = await _cookieManager.getCookies(_aulaUrl);
      debugPrint('Got ${allCookies.length} cookies from cookie manager (includes HttpOnly)');

      // Store structured cookies (includes HttpOnly session cookie)
      final storage = ref.read(sessionStorageProvider);
      await storage.saveCookies(allCookies);

      // Also store document.cookie for backward compatibility
      await storage.saveSessionCookie(documentCookies);
    } catch (e) {
      debugPrint('Failed to get cookies from cookie manager: $e');
      // Fall back to document.cookie only
      await ref.read(sessionStorageProvider).saveSessionCookie(documentCookies);
    }

    // Set cookies on the HTTP client (for non-auth requests)
    ref.read(aulaClientProvider).setSessionCookie(documentCookies);

    // Set the WebView controller on the WebView API client for authenticated requests
    setWebViewController(ref, _controller);

    // Complete login with profile data
    await ref.read(authNotifierProvider.notifier).completeLogin(profileData);

    // Hide the WebView — platform views ignore Offstage
    if (mounted) {
      setState(() => _loginComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // After login, render WebView at minimal size to keep controller alive
    // but prevent the platform view from rendering on top of Flutter widgets
    if (_loginComplete) {
      return SizedBox(
        width: 1,
        height: 1,
        child: WebViewWidget(controller: _controller),
      );
    }

    // Show full-screen spinner until we know user needs to manually login
    if (!_needsManualLogin && _error == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Keep WebView loading in background
            Offstage(
              offstage: true,
              child: WebViewWidget(controller: _controller),
            ),
            const Center(
              child: AppSpinner(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log ind med MitID'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
            onPressed: () {
              setState(() {
                _error = null;
                _isLoading = true;
                _loginInProgress = false;
              });
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: AppSpinner(),
              ),
            ),
          if (_error != null)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAlertCircle,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _isLoading = true;
                            _loginInProgress = false;
                          });
                          _controller.loadRequest(Uri.parse(_aulaUrl));
                        },
                        icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
                        label: const Text('Prøv igen'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
