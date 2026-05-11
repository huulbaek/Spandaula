/// Demo mode configuration
///
/// To record API responses:
///   flutter run --dart-define=RECORD_API=true
///
/// To use demo data:
///   flutter run --dart-define=DEMO_MODE=true
///
/// To hide the demo badge (for screencasts):
///   flutter run --dart-define=DEMO_MODE=true --dart-define=HIDE_DEMO_BADGE=true
class DemoConfig {
  /// Whether to record API responses to a file
  static const bool recordApi = bool.fromEnvironment('RECORD_API', defaultValue: false);

  /// Whether to use pre-recorded demo data instead of real API
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  /// Whether to hide the demo/recording badge (for clean screencasts)
  static const bool hideBadge = bool.fromEnvironment('HIDE_DEMO_BADGE', defaultValue: false);

  /// Whether either mode is active
  static bool get isActive => recordApi || demoMode;

  /// Whether to show the badge (active but not hidden)
  static bool get showBadge => isActive && !hideBadge;
}
