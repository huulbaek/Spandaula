import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'demo_config.dart';

/// Service for recording and playing back API responses for demo mode
class DemoDataService {
  static final DemoDataService _instance = DemoDataService._();
  static DemoDataService get instance => _instance;

  DemoDataService._();

  /// Recorded API responses: method -> list of responses (for pagination)
  final Map<String, List<dynamic>> _recordings = {};

  /// Playback data loaded from file
  Map<String, List<dynamic>>? _playbackData;

  /// Playback index for each method (to support multiple calls)
  final Map<String, int> _playbackIndex = {};

  /// File path for recordings
  Future<String> get _recordingPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/demo_data_raw.json';
  }

  /// Initialize the service
  Future<void> init() async {
    if (DemoConfig.demoMode) {
      await _loadPlaybackData();
    }
  }

  /// Load playback data from assets
  Future<void> _loadPlaybackData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/demo_data.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      _playbackData = data.map((key, value) => MapEntry(
        key,
        (value as List).cast<dynamic>(),
      ));
      debugPrint('DemoDataService: Loaded ${_playbackData!.length} API methods for playback');
    } catch (e) {
      debugPrint('DemoDataService: Failed to load demo data: $e');
      _playbackData = {};
    }
  }

  /// Record an API response
  Future<void> record(String method, Map<String, dynamic>? queryParams, dynamic response) async {
    if (!DemoConfig.recordApi) return;

    final key = _buildKey(method, queryParams);
    _recordings.putIfAbsent(key, () => []);
    _recordings[key]!.add(response);

    debugPrint('DemoDataService: Recorded $key (${_recordings[key]!.length} responses)');

    // Save after each recording
    await _saveRecordings();
  }

  /// Get playback data for a method
  dynamic getPlayback(String method, Map<String, dynamic>? queryParams) {
    if (!DemoConfig.demoMode || _playbackData == null) return null;

    // First try exact key match
    final exactKey = _buildKey(method, queryParams);
    var responses = _playbackData![exactKey];
    var matchedKey = exactKey;

    // If no exact match, try to find a key that matches the method name
    // and has the best parameter overlap with the requested params
    if (responses == null || responses.isEmpty) {
      final methodPrefix = '$method:';
      String? bestKey;
      int bestScore = -1;

      for (final key in _playbackData!.keys) {
        if (key == method || key.startsWith(methodPrefix)) {
          final keyResponses = _playbackData![key];
          if (keyResponses == null || keyResponses.isEmpty) continue;

          // Score based on how many query param values appear in the key
          int score = 0;
          if (queryParams != null) {
            for (final value in queryParams.values) {
              if (key.contains(value.toString())) {
                score += 1;
              }
            }
          }

          // Only use fuzzy match if no params to match, or at least one param matches
          if (queryParams == null || queryParams.isEmpty || score > 0) {
            if (score > bestScore) {
              bestScore = score;
              bestKey = key;
            }
          }
        }
      }

      if (bestKey != null) {
        responses = _playbackData![bestKey];
        matchedKey = bestKey;
        debugPrint('DemoDataService: Fuzzy match for $exactKey -> $bestKey (score: $bestScore)');
      }
    }

    if (responses == null || responses.isEmpty) {
      debugPrint('DemoDataService: No playback data for $method');
      return null;
    }

    // Use the matched key for the playback index so each unique request
    // (e.g., each threadId) cycles through its own responses independently
    final index = _playbackIndex[matchedKey] ?? 0;
    _playbackIndex[matchedKey] = (index + 1) % responses.length;

    debugPrint('DemoDataService: Playing back $matchedKey (index $index/${responses.length})');
    return responses[index];
  }

  /// Check if we have playback data for a method
  bool hasPlayback(String method, Map<String, dynamic>? queryParams) {
    if (!DemoConfig.demoMode || _playbackData == null) return false;

    // Check exact key
    final exactKey = _buildKey(method, queryParams);
    if (_playbackData!.containsKey(exactKey)) return true;

    // Check fuzzy match (method name only)
    final methodPrefix = '$method:';
    for (final key in _playbackData!.keys) {
      if (key == method || key.startsWith(methodPrefix)) {
        return true;
      }
    }
    return false;
  }

  /// Build a cache key from method and params
  String _buildKey(String method, Map<String, dynamic>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return method;
    }
    // Sort params for consistent keys
    final sortedParams = Map.fromEntries(
      queryParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return '$method:${jsonEncode(sortedParams)}';
  }

  /// Save recordings to file
  Future<void> _saveRecordings() async {
    try {
      final path = await _recordingPath;
      final file = File(path);
      final json = const JsonEncoder.withIndent('  ').convert(_recordings);
      await file.writeAsString(json);
      debugPrint('DemoDataService: Saved recordings to $path');
    } catch (e) {
      debugPrint('DemoDataService: Failed to save recordings: $e');
    }
  }

  /// Export recordings as JSON string (for copying from console)
  String exportRecordings() {
    return const JsonEncoder.withIndent('  ').convert(_recordings);
  }

  /// Export recordings as base64 (safe for console output)
  String exportRecordingsBase64() {
    final json = jsonEncode(_recordings); // Compact JSON
    final bytes = utf8.encode(json);
    return base64Encode(bytes);
  }

  /// Print all recordings to console as base64 (call this when done recording)
  void printRecordingsToConsole() {
    final b64 = exportRecordingsBase64();

    // Print as base64 in chunks (safe, no line break issues)
    debugPrint('');
    debugPrint('========== DEMO DATA BASE64 START ==========');
    debugPrint('Decode with: echo "BASE64_STRING" | base64 -d > demo_data_raw.json');
    debugPrint('Or paste into: https://www.base64decode.org/');
    debugPrint('');

    // Print in safe chunks
    const chunkSize = 500;
    for (var i = 0; i < b64.length; i += chunkSize) {
      final end = (i + chunkSize < b64.length) ? i + chunkSize : b64.length;
      debugPrint(b64.substring(i, end));
    }

    debugPrint('');
    debugPrint('========== DEMO DATA BASE64 END ==========');
    debugPrint('');
  }

  /// Get the number of recorded API calls
  int get recordingCount => _recordings.values.fold(0, (sum, list) => sum + list.length);

  /// Get the path where recordings are saved (for user info)
  Future<String> getRecordingPath() async {
    return _recordingPath;
  }

  /// Reset playback indices (useful when navigating back to start)
  void resetPlaybackIndices() {
    _playbackIndex.clear();
  }
}
