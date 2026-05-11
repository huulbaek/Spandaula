import '../../../core/models/message.dart';
import '../../../core/models/thread.dart';
import '../models/models.dart';
import '../protocol/protocol.dart';

/// Engine for managing Spandauer game state
///
/// Reconstructs game state from message history and validates/applies actions.
class SpandauerEngine {
  /// Reconstruct game state from a thread's messages
  static SpandauerGame? fromThread(
    Thread thread,
    List<Message> messages,
    int currentUserId,
  ) {
    // Extract all game events from messages
    final events = <GameEvent>[];
    String? gameId;

    for (final message in messages) {
      final event = SpandauerProtocol.decode(message.text, messageId: message.id);
      if (event != null) {
        gameId ??= event.gameId;
        if (event.gameId == gameId) {
          events.add(event);
        }
      }
    }

    if (events.isEmpty) return null;

    // Sort events by timestamp
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Replay events to build current state
    final game = _replayEvents(events, thread.id, gameId!);

    // Apply viewer perspective (hide other players' roles)
    return game.withPerspective(currentUserId);
  }

  /// Find all games in a list of threads
  static List<SpandauerGame> findGamesInThreads(
    List<Thread> threads,
    Map<int, List<Message>> threadMessages,
    int currentUserId,
  ) {
    final games = <SpandauerGame>[];

    for (final thread in threads) {
      final messages = threadMessages[thread.id] ?? [];
      final game = fromThread(thread, messages, currentUserId);
      if (game != null) {
        games.add(game);
      }
    }

    return games;
  }

  /// Replay events to build game state
  static SpandauerGame _replayEvents(
    List<GameEvent> events,
    int threadId,
    String gameId,
  ) {
    var game = SpandauerGame.initial().copyWith(
      id: gameId,
      threadId: threadId,
    );

    for (final event in events) {
      game = _applyEvent(game, event);
    }

    return game;
  }

  /// Apply a single event to game state
  static SpandauerGame _applyEvent(SpandauerGame game, GameEvent event) {
    switch (event.type) {
      case GameEventType.gameCreated:
        return _handleGameCreated(game, event);
      case GameEventType.rolesAssigned:
        return _handleRolesAssigned(game, event);
      case GameEventType.nightStarted:
        return _handleNightStarted(game, event);
      case GameEventType.dayStarted:
        return _handleDayStarted(game, event);
      case GameEventType.spandauerKill:
        return _handleSpandauerKill(game, event);
      case GameEventType.seerInvestigate:
        return _handleSeerInvestigate(game, event);
      case GameEventType.healerProtect:
        return _handleHealerProtect(game, event);
      case GameEventType.vote:
        return _handleVote(game, event);
      case GameEventType.playerKilled:
        return _handlePlayerKilled(game, event);
      case GameEventType.playerLynched:
        return _handlePlayerLynched(game, event);
      case GameEventType.gameEnded:
        return _handleGameEnded(game, event);
      default:
        return game.copyWith(
          events: [...game.events, event],
        );
    }
  }

  static SpandauerGame _handleGameCreated(SpandauerGame game, GameEvent event) {
    final playerIds = (event.data['playerIds'] as List).cast<int>();
    final gameName = event.data['gameName'] as String? ?? 'Spandauer';

    // Create player entries (roles will be assigned later)
    final players = playerIds
        .map((id) => GamePlayer(
              id: id,
              name: 'Spiller $id', // Will be populated from thread participants
            ))
        .toList();

    return game.copyWith(
      name: gameName,
      hostId: event.data['hostId'] as int,
      players: players,
      phase: GamePhase.lobby,
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleRolesAssigned(
      SpandauerGame game, GameEvent event) {
    // Note: Roles are encrypted, so we can't assign them here
    // Each player will decrypt their own role when viewing the game
    return game.copyWith(
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleNightStarted(SpandauerGame game, GameEvent event) {
    return game.copyWith(
      phase: GamePhase.night,
      phaseNumber: event.phaseNumber ?? game.phaseNumber + 1,
      pendingActions: {},
      nightKillTarget: null,
      healerProtectedId: null,
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleDayStarted(SpandauerGame game, GameEvent event) {
    return game.copyWith(
      phase: GamePhase.day,
      phaseNumber: event.phaseNumber ?? game.phaseNumber,
      currentVotes: {},
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleSpandauerKill(
      SpandauerGame game, GameEvent event) {
    return game.copyWith(
      nightKillTarget: event.targetId,
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleSeerInvestigate(
      SpandauerGame game, GameEvent event) {
    final actorId = event.actorId;
    if (actorId == null) return game;

    return game.copyWith(
      pendingActions: {...game.pendingActions, actorId: true},
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleHealerProtect(
      SpandauerGame game, GameEvent event) {
    return game.copyWith(
      healerProtectedId: event.targetId,
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleVote(SpandauerGame game, GameEvent event) {
    final voterId = event.actorId;
    final targetId = event.targetId;
    if (voterId == null || targetId == null) return game;

    return game.copyWith(
      currentVotes: {...game.currentVotes, voterId: targetId},
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handlePlayerKilled(SpandauerGame game, GameEvent event) {
    final victimId = event.victimId;
    if (victimId == null) return game;

    final updatedPlayers = game.players.map((p) {
      if (p.id == victimId) {
        return p.copyWith(status: PlayerStatus.dead);
      }
      return p;
    }).toList();

    return game.copyWith(
      players: updatedPlayers,
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handlePlayerLynched(
      SpandauerGame game, GameEvent event) {
    final victimId = event.victimId;
    if (victimId == null) return game;

    final updatedPlayers = game.players.map((p) {
      if (p.id == victimId) {
        return p.copyWith(status: PlayerStatus.dead);
      }
      return p;
    }).toList();

    return game.copyWith(
      players: updatedPlayers,
      currentVotes: {},
      events: [...game.events, event],
    );
  }

  static SpandauerGame _handleGameEnded(SpandauerGame game, GameEvent event) {
    return game.copyWith(
      phase: GamePhase.ended,
      events: [...game.events, event],
    );
  }

  /// Validate if an action is legal
  static bool isValidAction(SpandauerGame game, int playerId, GameEvent action) {
    final player = game.getPlayer(playerId);
    if (player == null || player.isDead) return false;

    switch (action.type) {
      case GameEventType.vote:
        if (!game.isDay) return false;
        if (game.currentVotes.containsKey(playerId)) return false;
        final targetId = action.targetId;
        if (targetId == null) return false;
        final target = game.getPlayer(targetId);
        return target != null && target.isAlive && target.id != playerId;

      case GameEventType.spandauerKill:
        if (!game.isNight) return false;
        if (player.role != Role.spandauer) return false;
        final targetId = action.targetId;
        if (targetId == null) return false;
        final target = game.getPlayer(targetId);
        return target != null && target.isAlive && target.role != Role.spandauer;

      case GameEventType.seerInvestigate:
        if (!game.isNight) return false;
        if (player.role != Role.seer) return false;
        if (game.pendingActions[playerId] == true) return false;
        final targetId = action.targetId;
        if (targetId == null) return false;
        final target = game.getPlayer(targetId);
        return target != null && target.isAlive && target.id != playerId;

      case GameEventType.healerProtect:
        if (!game.isNight) return false;
        if (player.role != Role.healer) return false;
        final targetId = action.targetId;
        if (targetId == null) return false;
        final target = game.getPlayer(targetId);
        return target != null && target.isAlive;

      default:
        return false;
    }
  }

  /// Count votes and determine if someone should be lynched
  static int? calculateLynchVictim(SpandauerGame game) {
    if (game.currentVotes.isEmpty) return null;

    // Count votes
    final voteCounts = <int, int>{};
    for (final targetId in game.currentVotes.values) {
      voteCounts[targetId] = (voteCounts[targetId] ?? 0) + 1;
    }

    // Find max votes
    int? maxVotes;
    int? victimId;
    for (final entry in voteCounts.entries) {
      if (maxVotes == null || entry.value > maxVotes) {
        maxVotes = entry.value;
        victimId = entry.key;
      } else if (entry.value == maxVotes) {
        // Tie - no one gets lynched
        victimId = null;
      }
    }

    // Need majority to lynch
    final majority = (game.alivePlayers.length / 2).ceil();
    if (maxVotes != null && maxVotes >= majority) {
      return victimId;
    }

    return null;
  }

  /// Resolve night phase - determine who dies
  static int? resolveNightKill(SpandauerGame game) {
    final target = game.nightKillTarget;
    if (target == null) return null;

    // Check if healer protected the target
    if (game.healerProtectedId == target) {
      return null; // Saved!
    }

    return target;
  }
}
