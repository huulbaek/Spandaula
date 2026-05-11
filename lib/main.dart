import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/auth/auth_service.dart';
import 'core/cache/cache_service.dart';
import 'core/demo/demo_config.dart';
import 'core/demo/demo_data_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/children/children_screen.dart';
import 'features/games/screens/games_list_screen.dart';
import 'features/wall/wall_screen.dart';
import 'features/messages/threads_screen.dart';
import 'shared/widgets/app_spinner.dart';
import 'shared/widgets/demo_mode_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for Danish
  await initializeDateFormatting('da_DK', null);

  // Initialize Hive
  await CacheService.initHive();

  // Initialize demo service if needed
  if (DemoConfig.isActive) {
    await DemoDataService.instance.init();
    if (DemoConfig.recordApi) {
      debugPrint('=== RECORDING MODE ACTIVE ===');
      debugPrint('API responses will be saved to: ${await DemoDataService.instance.getRecordingPath()}');
    }
    if (DemoConfig.demoMode) {
      debugPrint('=== DEMO MODE ACTIVE ===');
    }
  }

  runApp(
    const ProviderScope(
      child: AulaApp(),
    ),
  );
}

class AulaApp extends ConsumerWidget {
  const AulaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Aula',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8), // Aula blue
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0d1516),
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

/// Gate that shows login or main app based on auth state
/// Uses Stack to keep the LoginScreen's WebView alive for API calls
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  // Track if we've ever been authenticated to keep WebView alive
  bool _hasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Validate session when app comes back to foreground
      _validateSessionOnResume();
    }
  }

  Future<void> _validateSessionOnResume() async {
    final authService = ref.read(authServiceProvider);
    if (authService.currentState == AuthState.authenticated) {
      debugPrint('App resumed - validating session...');
      await authService.validateSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(
          child: AppSpinner(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedAlertCircle, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Fejl: $error', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(authNotifierProvider);
                  },
                  child: const Text('Prøv igen'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (state) {
        // Show spinner while auth state is still unknown (checking stored session)
        if (state == AuthState.unknown) {
          return const Scaffold(
            body: Center(
              child: AppSpinner(),
            ),
          );
        }

        final isAuthenticated = state == AuthState.authenticated;

        if (isAuthenticated && !_hasAuthenticated) {
          _hasAuthenticated = true;
        }

        // Use Stack to keep LoginScreen's WebView alive in background
        return Stack(
          children: [
            // Keep LoginScreen mounted but offstage when authenticated
            // This keeps the WebView alive for API calls
            Offstage(
              offstage: isAuthenticated,
              child: const LoginScreen(),
            ),
            // Show MainNavigation when authenticated
            if (isAuthenticated) const MainNavigation(),
          ],
        );
      },
    );
  }
}

/// Main app navigation with bottom nav bar
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    WallScreen(),
    ThreadsScreen(),
    ChildrenScreen(),
    GamesListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          // Demo mode indicator
          const DemoModeIndicator(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedDashboardSquare01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedDashboardSquare01),
            label: 'Væg',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedMail01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedMail01),
            label: 'Beskeder',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedBaby01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedBaby01),
            label: 'Børn',
          ),
          NavigationDestination(
            icon: Text('🥐', style: TextStyle(fontSize: 24)),
            selectedIcon: Text('🥐', style: TextStyle(fontSize: 24)),
            label: 'Spil',
          ),
          /* NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ), */
        ],
      ),
    );
  }
}

/// Simple profile screen with logout
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // Profile avatar and name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    profile != null ? _getInitials(profile.fullName) : '?',
                    style: TextStyle(
                      fontSize: 32,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile?.fullName ?? 'Ukendt',
                  style: theme.textTheme.headlineSmall,
                ),
                if (profile?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile!.email!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Children section
          if (profile != null && profile.children.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Børn',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...profile.children.map((child) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      _getInitials(child.fullName),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  title: Text(child.fullName),
                  subtitle: child.institutionName != null
                      ? Text(child.institutionName!)
                      : null,
                )),
            const Divider(height: 32),
          ],

          // Settings
          ListTile(
            leading: HugeIcon(icon: HugeIcons.strokeRoundedLogout01),
            title: const Text('Log ud'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log ud'),
                  content: const Text('Er du sikker på, at du vil logge ud?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Annuller'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Log ud'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref.read(authNotifierProvider.notifier).logout();
              }
            },
          ),

          const SizedBox(height: 24),

          // App info
          Center(
            child: Text(
              'Spandaula v0.1.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}
