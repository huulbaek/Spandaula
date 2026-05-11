import 'package:flutter_test/flutter_test.dart';
import 'package:spandaula/features/games/engine/engine.dart';
import 'package:spandaula/features/games/models/models.dart';

import '../test_helpers.dart';

void main() {
  group('SpandauerEngine', () {
    group('isValidAction - voting', () {
      test('valid: alive player votes during day', () {
        final game = testGame(
          phase: GamePhase.day,
          players: testPlayersWithRoles(),
        );

        final vote = GameEvent.vote(
          gameId: testGameId,
          voterId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], vote),
          isTrue,
        );
      });

      test('invalid: cannot vote during night', () {
        final game = testGame(
          phase: GamePhase.night,
          players: testPlayersWithRoles(),
        );

        final vote = GameEvent.vote(
          gameId: testGameId,
          voterId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], vote),
          isFalse,
        );
      });

      test('invalid: dead player cannot vote', () {
        final players = testPlayersWithRoles();
        final deadPlayers = [
          players[0].copyWith(status: PlayerStatus.dead),
          ...players.skip(1),
        ];

        final game = testGame(phase: GamePhase.day, players: deadPlayers);

        final vote = GameEvent.vote(
          gameId: testGameId,
          voterId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], vote),
          isFalse,
        );
      });

      test('invalid: cannot vote twice', () {
        final game = testGame(
          phase: GamePhase.day,
          players: testPlayersWithRoles(),
          currentVotes: {testPlayerIds[0]: testPlayerIds[2]}, // Already voted
        );

        final vote = GameEvent.vote(
          gameId: testGameId,
          voterId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], vote),
          isFalse,
        );
      });

      test('invalid: cannot vote for self', () {
        final game = testGame(
          phase: GamePhase.day,
          players: testPlayersWithRoles(),
        );

        final vote = GameEvent.vote(
          gameId: testGameId,
          voterId: testPlayerIds[0],
          targetId: testPlayerIds[0], // Voting for self
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], vote),
          isFalse,
        );
      });
    });

    group('isValidAction - spandauer kill', () {
      test('valid: spandauer kills during night', () {
        final players = [
          testPlayer(id: testPlayerIds[0], role: Role.spandauer),
          testPlayer(id: testPlayerIds[1], role: Role.villager),
          testPlayer(id: testPlayerIds[2], role: Role.villager),
        ];

        final game = testGame(phase: GamePhase.night, players: players);

        final kill = GameEvent.spandauerKill(
          gameId: testGameId,
          actorId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], kill),
          isTrue,
        );
      });

      test('invalid: cannot kill during day', () {
        final players = [
          testPlayer(id: testPlayerIds[0], role: Role.spandauer),
          testPlayer(id: testPlayerIds[1], role: Role.villager),
        ];

        final game = testGame(phase: GamePhase.day, players: players);

        final kill = GameEvent.spandauerKill(
          gameId: testGameId,
          actorId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], kill),
          isFalse,
        );
      });

      test('invalid: villager cannot use spandauer kill', () {
        final players = [
          testPlayer(id: testPlayerIds[0], role: Role.villager),
          testPlayer(id: testPlayerIds[1], role: Role.villager),
        ];

        final game = testGame(phase: GamePhase.night, players: players);

        final kill = GameEvent.spandauerKill(
          gameId: testGameId,
          actorId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], kill),
          isFalse,
        );
      });

      test('invalid: spandauer cannot kill another spandauer', () {
        final players = [
          testPlayer(id: testPlayerIds[0], role: Role.spandauer),
          testPlayer(id: testPlayerIds[1], role: Role.spandauer),
          testPlayer(id: testPlayerIds[2], role: Role.villager),
        ];

        final game = testGame(phase: GamePhase.night, players: players);

        final kill = GameEvent.spandauerKill(
          gameId: testGameId,
          actorId: testPlayerIds[0],
          targetId: testPlayerIds[1], // Another spandauer
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], kill),
          isFalse,
        );
      });
    });

    group('isValidAction - seer investigate', () {
      test('valid: seer investigates during night', () {
        final players = [
          testPlayer(id: testPlayerIds[0], role: Role.seer),
          testPlayer(id: testPlayerIds[1], role: Role.villager),
        ];

        final game = testGame(phase: GamePhase.night, players: players);

        final investigate = GameEvent.seerInvestigate(
          gameId: testGameId,
          actorId: testPlayerIds[0],
          targetId: testPlayerIds[1],
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], investigate),
          isTrue,
        );
      });

      test('invalid: seer cannot investigate self', () {
        final players = [
          testPlayer(id: testPlayerIds[0], role: Role.seer),
          testPlayer(id: testPlayerIds[1], role: Role.villager),
        ];

        final game = testGame(phase: GamePhase.night, players: players);

        final investigate = GameEvent.seerInvestigate(
          gameId: testGameId,
          actorId: testPlayerIds[0],
          targetId: testPlayerIds[0], // Self
        );

        expect(
          SpandauerEngine.isValidAction(game, testPlayerIds[0], investigate),
          isFalse,
        );
      });
    });

    group('calculateLynchVictim', () {
      test('returns player with majority votes', () {
        final game = testGame(
          phase: GamePhase.day,
          players: [
            testPlayer(id: 1, role: Role.villager),
            testPlayer(id: 2, role: Role.villager),
            testPlayer(id: 3, role: Role.villager),
            testPlayer(id: 4, role: Role.spandauer),
          ],
          currentVotes: {
            1: 4, // Player 1 votes for 4
            2: 4, // Player 2 votes for 4
            3: 4, // Player 3 votes for 4
            4: 1, // Player 4 votes for 1
          },
        );

        final victim = SpandauerEngine.calculateLynchVictim(game);

        expect(victim, equals(4));
      });

      test('returns null for tie', () {
        final game = testGame(
          phase: GamePhase.day,
          players: [
            testPlayer(id: 1, role: Role.villager),
            testPlayer(id: 2, role: Role.villager),
            testPlayer(id: 3, role: Role.villager),
            testPlayer(id: 4, role: Role.spandauer),
          ],
          currentVotes: {
            1: 3, // Votes for 3
            2: 4, // Votes for 4
            3: 4, // Votes for 4
            4: 3, // Votes for 3
          },
        );

        final victim = SpandauerEngine.calculateLynchVictim(game);

        // 3 and 4 both have 2 votes - tie
        expect(victim, isNull);
      });

      test('returns null when no votes', () {
        final game = testGame(
          phase: GamePhase.day,
          players: testPlayersWithRoles(),
          currentVotes: {},
        );

        final victim = SpandauerEngine.calculateLynchVictim(game);

        expect(victim, isNull);
      });

      test('returns null when no majority', () {
        final game = testGame(
          phase: GamePhase.day,
          players: [
            testPlayer(id: 1, role: Role.villager),
            testPlayer(id: 2, role: Role.villager),
            testPlayer(id: 3, role: Role.villager),
            testPlayer(id: 4, role: Role.villager),
            testPlayer(id: 5, role: Role.spandauer),
          ],
          currentVotes: {
            1: 5, // 1 vote for 5
            2: 3, // 1 vote for 3
            // Only 2 out of 5 have voted, and no majority
          },
        );

        final victim = SpandauerEngine.calculateLynchVictim(game);

        expect(victim, isNull);
      });
    });

    group('resolveNightKill', () {
      test('returns target when not protected', () {
        final game = testGame(
          phase: GamePhase.night,
          players: testPlayersWithRoles(),
          nightKillTarget: testPlayerIds[2],
          healerProtectedId: testPlayerIds[1], // Different player protected
        );

        final victim = SpandauerEngine.resolveNightKill(game);

        expect(victim, equals(testPlayerIds[2]));
      });

      test('returns null when target is protected', () {
        final game = testGame(
          phase: GamePhase.night,
          players: testPlayersWithRoles(),
          nightKillTarget: testPlayerIds[2],
          healerProtectedId: testPlayerIds[2], // Same player protected
        );

        final victim = SpandauerEngine.resolveNightKill(game);

        expect(victim, isNull);
      });

      test('returns null when no kill target', () {
        final game = testGame(
          phase: GamePhase.night,
          players: testPlayersWithRoles(),
          nightKillTarget: null,
        );

        final victim = SpandauerEngine.resolveNightKill(game);

        expect(victim, isNull);
      });

      test('returns target when no healer protection', () {
        final game = testGame(
          phase: GamePhase.night,
          players: testPlayersWithRoles(),
          nightKillTarget: testPlayerIds[2],
          healerProtectedId: null,
        );

        final victim = SpandauerEngine.resolveNightKill(game);

        expect(victim, equals(testPlayerIds[2]));
      });
    });
  });
}
