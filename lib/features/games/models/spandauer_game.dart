import 'game_enums.dart';
import 'game_event.dart';
import 'game_player.dart';

/// A Spandauer game instance
class SpandauerGame {
  /// Unique game identifier
  final String id;

  /// Aula message thread ID used for game communication
  final int threadId;

  /// Game name/title
  final String name;

  /// Player who created the game
  final int hostId;

  /// Current game phase
  final GamePhase phase;

  /// Current day/night number (starts at 1)
  final int phaseNumber;

  /// All players in the game
  final List<GamePlayer> players;

  /// All game events (chronologically ordered)
  final List<GameEvent> events;

  /// Current phase's pending actions (player ID -> has acted)
  final Map<int, bool> pendingActions;

  /// Current votes (voter ID -> target ID)
  final Map<int, int> currentVotes;

  /// Night kill target (spandauer consensus)
  final int? nightKillTarget;

  /// Player protected by healer this night
  final int? healerProtectedId;

  const SpandauerGame({
    required this.id,
    required this.threadId,
    required this.name,
    required this.hostId,
    required this.phase,
    this.phaseNumber = 0,
    this.players = const [],
    this.events = const [],
    this.pendingActions = const {},
    this.currentVotes = const {},
    this.nightKillTarget,
    this.healerProtectedId,
  });

  /// Get initial empty game state
  factory SpandauerGame.initial() {
    return const SpandauerGame(
      id: '',
      threadId: 0,
      name: '',
      hostId: 0,
      phase: GamePhase.lobby,
    );
  }

  // Derived properties

  /// All alive players
  List<GamePlayer> get alivePlayers =>
      players.where((p) => p.isAlive).toList();

  /// All dead players
  List<GamePlayer> get deadPlayers => players.where((p) => p.isDead).toList();

  /// Alive spandauers
  List<GamePlayer> get aliveSpandauers =>
      alivePlayers.where((p) => p.role == Role.spandauer).toList();

  /// Alive villagers (non-spandauer team)
  List<GamePlayer> get aliveVillagers =>
      alivePlayers.where((p) => p.role != Role.spandauer).toList();

  /// Check if game has ended
  bool get isEnded => phase == GamePhase.ended;

  /// Check if game is still in lobby
  bool get isLobby => phase == GamePhase.lobby;

  /// Check if it's night phase
  bool get isNight => phase == GamePhase.night;

  /// Check if it's day phase
  bool get isDay => phase == GamePhase.day;

  /// Get the winning team (null if game not ended)
  Team? get winner {
    if (!isEnded) return null;
    final endEvent = events.lastWhere(
      (e) => e.type == GameEventType.gameEnded,
      orElse: () => throw StateError('Game ended but no end event'),
    );
    return endEvent.winningTeam;
  }

  /// Check win conditions
  Team? checkWinCondition() {
    if (aliveSpandauers.isEmpty) {
      return Team.villagers;
    }
    if (aliveSpandauers.length >= aliveVillagers.length) {
      return Team.spandauers;
    }
    return null;
  }

  /// Get a player by ID
  GamePlayer? getPlayer(int id) {
    try {
      return players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get player with perspective (only shows own role, or all roles if dead/ended)
  SpandauerGame withPerspective(int viewerId) {
    final viewer = getPlayer(viewerId);
    final canSeeAllRoles = isEnded || (viewer?.isDead ?? false);

    if (canSeeAllRoles) {
      return this;
    }

    // Hide other players' roles
    final maskedPlayers = players.map((p) {
      if (p.id == viewerId) {
        return p; // Show own role
      }
      if (p.isDead) {
        return p; // Show dead players' roles
      }
      return p.copyWith(role: null); // Hide living players' roles
    }).toList();

    return copyWith(players: maskedPlayers);
  }

  /// Check if a player needs to take action
  bool needsAction(int playerId) {
    final player = getPlayer(playerId);
    if (player == null || player.isDead) return false;

    if (isDay) {
      // Everyone alive needs to vote
      return !currentVotes.containsKey(playerId);
    }

    if (isNight) {
      switch (player.role) {
        case Role.spandauer:
          return nightKillTarget == null;
        case Role.seer:
          return pendingActions[playerId] != true;
        case Role.healer:
          return healerProtectedId == null;
        default:
          return false;
      }
    }

    return false;
  }

  /// Get available targets for a player's action
  List<GamePlayer> getValidTargets(int playerId) {
    final player = getPlayer(playerId);
    if (player == null || player.isDead) return [];

    if (isDay) {
      // Can vote for any alive player except self
      return alivePlayers.where((p) => p.id != playerId).toList();
    }

    if (isNight) {
      switch (player.role) {
        case Role.spandauer:
          // Spandauers can target non-spandauers
          return alivePlayers
              .where((p) => p.role != Role.spandauer)
              .toList();
        case Role.seer:
          // Seer can investigate any alive player except self
          return alivePlayers.where((p) => p.id != playerId).toList();
        case Role.healer:
          // Healer can protect any alive player
          return alivePlayers;
        default:
          return [];
      }
    }

    return [];
  }

  SpandauerGame copyWith({
    String? id,
    int? threadId,
    String? name,
    int? hostId,
    GamePhase? phase,
    int? phaseNumber,
    List<GamePlayer>? players,
    List<GameEvent>? events,
    Map<int, bool>? pendingActions,
    Map<int, int>? currentVotes,
    int? nightKillTarget,
    int? healerProtectedId,
  }) {
    return SpandauerGame(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      phase: phase ?? this.phase,
      phaseNumber: phaseNumber ?? this.phaseNumber,
      players: players ?? this.players,
      events: events ?? this.events,
      pendingActions: pendingActions ?? this.pendingActions,
      currentVotes: currentVotes ?? this.currentVotes,
      nightKillTarget: nightKillTarget ?? this.nightKillTarget,
      healerProtectedId: healerProtectedId ?? this.healerProtectedId,
    );
  }
}
