/// Shared test utilities for Spandauer game tests
library;

import 'package:spandaula/features/games/models/models.dart';

// Common test player IDs
const testPlayerIds = [101, 102, 103, 104, 105, 106];

// Test game ID
const testGameId = 'sp_test123';

// Test game salt for encryption
const testGameSalt = 'dGVzdHNhbHQxMjM0NTY='; // base64 encoded "testsalt123456"

/// Create a test player with defaults
GamePlayer testPlayer({
  required int id,
  String? name,
  Role? role,
  PlayerStatus status = PlayerStatus.alive,
}) {
  return GamePlayer(
    id: id,
    name: name ?? 'Spiller $id',
    role: role,
    status: status,
  );
}

/// Create a list of test players with roles assigned
List<GamePlayer> testPlayersWithRoles({
  int spandauerCount = 1,
  bool includeSeer = true,
  bool includeHealer = false,
  int totalPlayers = 5,
}) {
  final players = <GamePlayer>[];
  var roleIndex = 0;

  // Add spandauers
  for (var i = 0; i < spandauerCount && roleIndex < totalPlayers; i++) {
    players.add(testPlayer(
      id: testPlayerIds[roleIndex++],
      role: Role.spandauer,
    ));
  }

  // Add seer
  if (includeSeer && roleIndex < totalPlayers) {
    players.add(testPlayer(
      id: testPlayerIds[roleIndex++],
      role: Role.seer,
    ));
  }

  // Add healer
  if (includeHealer && roleIndex < totalPlayers) {
    players.add(testPlayer(
      id: testPlayerIds[roleIndex++],
      role: Role.healer,
    ));
  }

  // Fill rest with villagers
  while (roleIndex < totalPlayers) {
    players.add(testPlayer(
      id: testPlayerIds[roleIndex++],
      role: Role.villager,
    ));
  }

  return players;
}

/// Create a test game in a specific phase
SpandauerGame testGame({
  String? id,
  GamePhase phase = GamePhase.day,
  List<GamePlayer>? players,
  Map<int, int>? currentVotes,
  int? nightKillTarget,
  int? healerProtectedId,
  int phaseNumber = 1,
}) {
  return SpandauerGame(
    id: id ?? testGameId,
    threadId: 999,
    name: 'Test Spil',
    hostId: testPlayerIds[0],
    phase: phase,
    phaseNumber: phaseNumber,
    players: players ?? testPlayersWithRoles(),
    currentVotes: currentVotes ?? {},
    nightKillTarget: nightKillTarget,
    healerProtectedId: healerProtectedId,
  );
}
