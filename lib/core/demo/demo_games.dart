/// Demo game data for showcasing the Spandauer game without Aula login
library;

import '../../features/games/models/models.dart';

/// Fake player data for demo games
const demoGamePlayers = [
  {'id': 1000001, 'name': 'Anders Hansen'},
  {'id': 1000101, 'name': 'Sofie Nielsen'},
  {'id': 1000102, 'name': 'Magnus Pedersen'},
  {'id': 1000103, 'name': 'Freja Christensen'},
  {'id': 1000104, 'name': 'Oscar Larsen'},
  {'id': 1000105, 'name': 'Ida Andersen'},
  {'id': 1000106, 'name': 'Victor Mortensen'},
  {'id': 1000107, 'name': 'Clara Jørgensen'},
];

/// Get all demo games
List<SpandauerGame> getDemoGames() {
  return [
    _nightPhaseGame(),
    _dayPhaseGame(),
    _completedGame(),
  ];
}

/// Get a demo game by ID
SpandauerGame? getDemoGameById(String gameId) {
  return getDemoGames().where((g) => g.id == gameId).firstOrNull;
}

/// Get the demo user's role in a game
Role? getDemoUserRole(String gameId) {
  switch (gameId) {
    case 'demo_night':
      return Role.seer; // Demo user is seer in night game
    case 'demo_day':
      return Role.villager; // Demo user is villager in day game
    case 'demo_ended':
      return Role.villager; // Demo user was villager in ended game
    default:
      return null;
  }
}

/// Demo game 1: Night phase - player is seer, needs to investigate
SpandauerGame _nightPhaseGame() {
  final players = [
    const GamePlayer(
      id: 1000001,
      name: 'Anders Hansen',
      role: Role.seer, // Demo user's role (only they can see this)
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000101,
      name: 'Sofie Nielsen',
      role: Role.spandauer, // Hidden from demo user
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000102,
      name: 'Magnus Pedersen',
      role: Role.villager,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000103,
      name: 'Freja Christensen',
      role: Role.healer,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000104,
      name: 'Oscar Larsen',
      role: Role.villager,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000105,
      name: 'Ida Andersen',
      role: Role.villager,
      status: PlayerStatus.alive,
    ),
  ];

  return SpandauerGame(
    id: 'demo_night',
    threadId: 9001,
    name: 'Nattens Mysterium',
    hostId: 1000101,
    phase: GamePhase.night,
    phaseNumber: 2,
    players: players,
    events: [
      GameEvent(
        id: 'e1',
        gameId: 'demo_night',
        type: GameEventType.gameCreated,
        data: {
          'hostId': 1000101,
          'gameName': 'Nattens Mysterium',
          'playerIds': players.map((p) => p.id).toList(),
        },
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      GameEvent(
        id: 'e2',
        gameId: 'demo_night',
        type: GameEventType.nightStarted,
        data: {'phaseNumber': 1},
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
      ),
      GameEvent(
        id: 'e3',
        gameId: 'demo_night',
        type: GameEventType.dayStarted,
        data: {'phaseNumber': 1},
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
      ),
      GameEvent(
        id: 'e4',
        gameId: 'demo_night',
        type: GameEventType.nightStarted,
        data: {'phaseNumber': 2},
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    ],
    pendingActions: {}, // Seer hasn't acted yet
    nightKillTarget: null,
    healerProtectedId: null,
  );
}

/// Demo game 2: Day phase - player is villager, voting in progress
SpandauerGame _dayPhaseGame() {
  final players = [
    const GamePlayer(
      id: 1000001,
      name: 'Anders Hansen',
      role: Role.villager,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000102,
      name: 'Magnus Pedersen',
      role: Role.spandauer, // Hidden
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000103,
      name: 'Freja Christensen',
      role: Role.seer,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000104,
      name: 'Oscar Larsen',
      role: Role.villager,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000105,
      name: 'Ida Andersen',
      role: Role.villager,
      status: PlayerStatus.dead, // Killed last night
    ),
    const GamePlayer(
      id: 1000106,
      name: 'Victor Mortensen',
      role: Role.healer,
      status: PlayerStatus.alive,
    ),
  ];

  return SpandauerGame(
    id: 'demo_day',
    threadId: 9002,
    name: 'Landsbyen',
    hostId: 1000102,
    phase: GamePhase.day,
    phaseNumber: 2,
    players: players,
    events: [
      GameEvent(
        id: 'd1',
        gameId: 'demo_day',
        type: GameEventType.gameCreated,
        data: {
          'hostId': 1000102,
          'gameName': 'Landsbyen',
          'playerIds': players.map((p) => p.id).toList(),
        },
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      GameEvent(
        id: 'd2',
        gameId: 'demo_day',
        type: GameEventType.playerKilled,
        data: {'victimId': 1000105},
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      GameEvent(
        id: 'd3',
        gameId: 'demo_day',
        type: GameEventType.dayStarted,
        data: {'phaseNumber': 2},
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ],
    currentVotes: {
      1000103: 1000102, // Freja votes for Magnus (the actual spandauer!)
      1000106: 1000104, // Victor votes for Oscar
    },
    nightKillTarget: null,
    healerProtectedId: null,
  );
}

/// Demo game 3: Completed - villagers won
SpandauerGame _completedGame() {
  final players = [
    const GamePlayer(
      id: 1000001,
      name: 'Anders Hansen',
      role: Role.villager,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000101,
      name: 'Sofie Nielsen',
      role: Role.spandauer, // Revealed after game
      status: PlayerStatus.dead, // Lynched
    ),
    const GamePlayer(
      id: 1000102,
      name: 'Magnus Pedersen',
      role: Role.seer,
      status: PlayerStatus.alive,
    ),
    const GamePlayer(
      id: 1000103,
      name: 'Freja Christensen',
      role: Role.villager,
      status: PlayerStatus.dead, // Killed by spandauer
    ),
    const GamePlayer(
      id: 1000104,
      name: 'Oscar Larsen',
      role: Role.villager,
      status: PlayerStatus.alive,
    ),
  ];

  return SpandauerGame(
    id: 'demo_ended',
    threadId: 9003,
    name: 'Det Store Spil',
    hostId: 1000001,
    phase: GamePhase.ended,
    phaseNumber: 3,
    players: players,
    events: [
      GameEvent(
        id: 'c1',
        gameId: 'demo_ended',
        type: GameEventType.gameCreated,
        data: {
          'hostId': 1000001,
          'gameName': 'Det Store Spil',
          'playerIds': players.map((p) => p.id).toList(),
        },
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      ),
      GameEvent(
        id: 'c2',
        gameId: 'demo_ended',
        type: GameEventType.playerKilled,
        data: {'victimId': 1000103},
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
      GameEvent(
        id: 'c3',
        gameId: 'demo_ended',
        type: GameEventType.playerLynched,
        data: {
          'victimId': 1000101,
          'voteResults': {'1000001': 1000101, '1000102': 1000101, '1000104': 1000101},
        },
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      GameEvent(
        id: 'c4',
        gameId: 'demo_ended',
        type: GameEventType.gameEnded,
        data: {'winningTeam': 'villagers'},
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
    currentVotes: {},
    nightKillTarget: null,
    healerProtectedId: null,
  );
}
