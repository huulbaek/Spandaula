import 'dart:convert';

import '../models/models.dart';

/// Protocol for encoding/decoding Spandauer game events as messages
///
/// Messages are encoded as base64 JSON with a special prefix emoji
/// so that the app can identify game messages in a thread.
class SpandauerProtocol {
  /// Prefix that identifies game messages
  static const String prefix = '🎮';

  /// Current protocol version
  static const int version = 1;

  /// Encode a game event to a message string
  static String encode(GameEvent event) {
    final payload = {
      'v': version,
      'g': event.gameId,
      't': event.type.name,
      'd': event.data,
      'ts': event.timestamp.toIso8601String(),
      if (event.actorId != null) 'a': event.actorId,
    };

    final json = jsonEncode(payload);
    final encoded = base64Encode(utf8.encode(json));
    return '$prefix$encoded';
  }

  /// Decode a message string to a game event
  /// Returns null if the message is not a valid game message
  static GameEvent? decode(String message, {String? messageId}) {
    if (!isGameMessage(message)) return null;

    try {
      final encoded = message.substring(prefix.length);
      final json = utf8.decode(base64Decode(encoded));
      final payload = jsonDecode(json) as Map<String, dynamic>;

      // Version check
      final messageVersion = payload['v'] as int?;
      if (messageVersion == null || messageVersion > version) {
        return null; // Incompatible version
      }

      return GameEvent(
        id: messageId ?? payload['ts'] as String,
        gameId: payload['g'] as String,
        type: GameEventType.values.firstWhere(
          (t) => t.name == payload['t'],
          orElse: () => throw FormatException('Unknown event type: ${payload['t']}'),
        ),
        data: Map<String, dynamic>.from(payload['d'] as Map),
        timestamp: DateTime.parse(payload['ts'] as String),
        actorId: payload['a'] as int?,
        sourceMessageId: messageId,
      );
    } catch (e) {
      // Not a valid game message
      return null;
    }
  }

  /// Check if a message is a game message (starts with prefix)
  static bool isGameMessage(String message) {
    return message.startsWith(prefix);
  }

  /// Extract game ID from a message without full decoding
  static String? extractGameId(String message) {
    if (!isGameMessage(message)) return null;

    try {
      final encoded = message.substring(prefix.length);
      final json = utf8.decode(base64Decode(encoded));
      final payload = jsonDecode(json) as Map<String, dynamic>;
      return payload['g'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Generate a unique game ID
  static String generateGameId() {
    final now = DateTime.now();
    final random = now.microsecondsSinceEpoch.toRadixString(36);
    return 'sp_$random';
  }
}
