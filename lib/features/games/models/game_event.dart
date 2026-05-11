import 'game_enums.dart';

/// An event in a Spandauer game, reconstructed from a message
class GameEvent {
  /// Unique event ID (typically from the message ID)
  final String id;

  /// Game this event belongs to
  final String gameId;

  /// Type of event
  final GameEventType type;

  /// Event data (varies by type)
  final Map<String, dynamic> data;

  /// When the event occurred
  final DateTime timestamp;

  /// ID of the player who initiated this event (if applicable)
  final int? actorId;

  /// ID of the message this event was decoded from
  final String? sourceMessageId;

  const GameEvent({
    required this.id,
    required this.gameId,
    required this.type,
    required this.data,
    required this.timestamp,
    this.actorId,
    this.sourceMessageId,
  });

  // Helper getters for common event data

  /// For vote events: who was voted for
  int? get targetId => data['targetId'] as int?;

  /// For role assignment: encrypted role data per player
  Map<String, String>? get encryptedRoles =>
      (data['roles'] as Map<String, dynamic>?)?.cast<String, String>();

  /// For kill/lynch events: who died
  int? get victimId => data['victimId'] as int?;

  /// For seer result: whether target is a spandauer
  bool? get isSpandauer => data['isSpandauer'] as bool?;

  /// For game end: winning team
  Team? get winningTeam => data['winningTeam'] != null
      ? Team.values.firstWhere((t) => t.name == data['winningTeam'])
      : null;

  /// For phase transitions: which day/night number
  int? get phaseNumber => data['phaseNumber'] as int?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameId': gameId,
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'actorId': actorId,
        'sourceMessageId': sourceMessageId,
      };

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      type: GameEventType.values.firstWhere((t) => t.name == json['type']),
      data: Map<String, dynamic>.from(json['data'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
      actorId: json['actorId'] as int?,
      sourceMessageId: json['sourceMessageId'] as String?,
    );
  }

  /// Create a game created event
  factory GameEvent.gameCreated({
    required String gameId,
    required int hostId,
    required String gameName,
    required List<int> playerIds,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.gameCreated,
      data: {
        'hostId': hostId,
        'gameName': gameName,
        'playerIds': playerIds,
      },
      timestamp: DateTime.now(),
      actorId: hostId,
    );
  }

  /// Create a roles assigned event
  factory GameEvent.rolesAssigned({
    required String gameId,
    required int hostId,
    required Map<String, String> encryptedRoles,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.rolesAssigned,
      data: {'roles': encryptedRoles},
      timestamp: DateTime.now(),
      actorId: hostId,
    );
  }

  /// Create a night started event
  factory GameEvent.nightStarted({
    required String gameId,
    required int nightNumber,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.nightStarted,
      data: {'phaseNumber': nightNumber},
      timestamp: DateTime.now(),
    );
  }

  /// Create a day started event
  factory GameEvent.dayStarted({
    required String gameId,
    required int dayNumber,
    int? killedPlayerId,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.dayStarted,
      data: {
        'phaseNumber': dayNumber,
        if (killedPlayerId != null) 'killedPlayerId': killedPlayerId,
      },
      timestamp: DateTime.now(),
    );
  }

  /// Create a spandauer kill action
  factory GameEvent.spandauerKill({
    required String gameId,
    required int actorId,
    required int targetId,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.spandauerKill,
      data: {'targetId': targetId},
      timestamp: DateTime.now(),
      actorId: actorId,
    );
  }

  /// Create a seer investigate action
  factory GameEvent.seerInvestigate({
    required String gameId,
    required int actorId,
    required int targetId,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.seerInvestigate,
      data: {'targetId': targetId},
      timestamp: DateTime.now(),
      actorId: actorId,
    );
  }

  /// Create a seer result event (sent privately)
  factory GameEvent.seerResult({
    required String gameId,
    required int targetId,
    required bool isSpandauer,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.seerResult,
      data: {
        'targetId': targetId,
        'isSpandauer': isSpandauer,
      },
      timestamp: DateTime.now(),
    );
  }

  /// Create a healer protect action
  factory GameEvent.healerProtect({
    required String gameId,
    required int actorId,
    required int targetId,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.healerProtect,
      data: {'targetId': targetId},
      timestamp: DateTime.now(),
      actorId: actorId,
    );
  }

  /// Create a vote event
  factory GameEvent.vote({
    required String gameId,
    required int voterId,
    required int targetId,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.vote,
      data: {'targetId': targetId},
      timestamp: DateTime.now(),
      actorId: voterId,
    );
  }

  /// Create a player killed event (night kill)
  factory GameEvent.playerKilled({
    required String gameId,
    required int victimId,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.playerKilled,
      data: {'victimId': victimId},
      timestamp: DateTime.now(),
    );
  }

  /// Create a player lynched event (day vote)
  factory GameEvent.playerLynched({
    required String gameId,
    required int victimId,
    required Map<int, int> voteResults,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.playerLynched,
      data: {
        'victimId': victimId,
        'voteResults': voteResults.map((k, v) => MapEntry(k.toString(), v)),
      },
      timestamp: DateTime.now(),
    );
  }

  /// Create a game ended event
  factory GameEvent.gameEnded({
    required String gameId,
    required Team winningTeam,
  }) {
    return GameEvent(
      id: _generateId(),
      gameId: gameId,
      type: GameEventType.gameEnded,
      data: {'winningTeam': winningTeam.name},
      timestamp: DateTime.now(),
    );
  }

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}
