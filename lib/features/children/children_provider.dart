import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/webview_api_client.dart';
import '../../core/models/calendar_event.dart';
import '../../core/models/profile.dart';
import '../auth/auth_provider.dart';

/// State for reporting a child sick
class ReportSickState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const ReportSickState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  ReportSickState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return ReportSickState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Notifier for children screen and sick reporting
class ChildrenNotifier extends StateNotifier<ReportSickState> {
  final WebViewApiClient _client;

  ChildrenNotifier(this._client) : super(const ReportSickState());

  /// Fetch today's calendar events for a child
  Future<List<CalendarEvent>> _fetchTodaysEvents(int instProfileId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    // Format dates for Aula API
    final startStr = _formatDateTime(startOfDay);
    final endStr = _formatDateTime(endOfDay);

    debugPrint('ChildrenProvider: Fetching events for instProfileId=$instProfileId, start=$startStr, end=$endStr');

    final data = await _client.post(
      ApiEndpoints.getEventsByProfileIds,
      body: {
        'instProfileIds': [instProfileId],
        'resourceIds': [],
        'start': startStr,
        'end': endStr,
      },
    );

    final events = <CalendarEvent>[];
    if (data is List) {
      for (final item in data) {
        try {
          events.add(CalendarEvent.fromJson(item));
        } catch (e) {
          debugPrint('ChildrenProvider: Error parsing event: $e');
        }
      }
    }

    debugPrint('ChildrenProvider: Found ${events.length} events');
    return events;
  }

  /// Format datetime for Aula API (e.g., "2026-01-22 00:00:00.0000+01:00")
  String _formatDateTime(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final offsetSign = offset.isNegative ? '-' : '+';

    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}'
        '.${dt.millisecond.toString().padLeft(4, '0')}$offsetSign$offsetHours:$offsetMinutes';
  }

  /// Report a child sick
  Future<bool> reportSick({
    required ChildProfile child,
    required String parentName,
  }) async {
    if (child.institutionProfileId == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Barnet har ikke et gyldigt institutionsprofil-ID',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      // 1. Fetch today's events
      final events = await _fetchTodaysEvents(child.institutionProfileId!);

      // 2. Filter for lessons and sort by start time
      final lessons = events
          .where((e) => e.type == 'lesson' && e.lesson != null)
          .toList()
        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

      if (lessons.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Ingen timer i dag - kan ikke finde en lærer at sende besked til',
        );
        return false;
      }

      // 3. Get first lesson's primary teacher
      final firstLesson = lessons.first;
      final primaryTeacher = firstLesson.lesson!.primaryTeacher;

      if (primaryTeacher == null || primaryTeacher.teacherId == 0) {
        state = state.copyWith(
          isLoading: false,
          error: 'Kunne ikke finde lærer for første time (${firstLesson.title})',
        );
        return false;
      }

      debugPrint('ChildrenProvider: First lesson: ${firstLesson.title}');
      debugPrint('ChildrenProvider: Teacher: ${primaryTeacher.teacherName} (ID: ${primaryTeacher.teacherId})');

      // 4. Compose and send the message
      final teacherName = primaryTeacher.teacherName ?? 'Lærer';
      final messageText = 'Kære $teacherName\n\n'
          '${child.fullName} er desværre syg i dag.\n\n'
          'Med venlig hilsen\n'
          '$parentName';

      final htmlMessage = '<div>${messageText.replaceAll('\n', '<br>')}</div>';

      await _client.post(
        ApiEndpoints.startNewThread,
        body: {
          'recipientInstitutionProfileIds': [primaryTeacher.teacherId],
          'subject': 'Sygdom',
          'message': {'text': htmlMessage},
          'attachmentIds': [],
        },
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Besked sendt til ${primaryTeacher.teacherName ?? 'lærer'} om at ${child.firstName} er syg',
      );
      return true;
    } catch (e) {
      debugPrint('ChildrenProvider: Error reporting sick: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Fejl ved afsendelse: $e',
      );
      return false;
    }
  }

  /// Clear state
  void clearState() {
    state = const ReportSickState();
  }
}

/// Children notifier provider
final childrenProvider = StateNotifierProvider<ChildrenNotifier, ReportSickState>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  return ChildrenNotifier(client);
});
