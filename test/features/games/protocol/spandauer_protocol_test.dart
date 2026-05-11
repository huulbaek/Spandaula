import 'package:flutter_test/flutter_test.dart';
import 'package:spandaula/features/games/models/models.dart';
import 'package:spandaula/features/games/protocol/protocol.dart';

void main() {
  group('SpandauerProtocol', () {
    group('encode/decode roundtrip', () {
      test('encodes and decodes vote event correctly', () {
        final event = GameEvent.vote(
          gameId: 'sp_test123',
          voterId: 101,
          targetId: 102,
        );

        final encoded = SpandauerProtocol.encode(event);
        final decoded = SpandauerProtocol.decode(encoded, messageId: 'msg1');

        expect(decoded, isNotNull);
        expect(decoded!.gameId, equals('sp_test123'));
        expect(decoded.type, equals(GameEventType.vote));
        expect(decoded.actorId, equals(101));
        expect(decoded.targetId, equals(102));
      });

      test('encodes and decodes gameCreated event correctly', () {
        final event = GameEvent.gameCreated(
          gameId: 'sp_abc',
          hostId: 100,
          gameName: 'Testspil',
          playerIds: [100, 101, 102, 103, 104],
        );

        final encoded = SpandauerProtocol.encode(event);
        final decoded = SpandauerProtocol.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.type, equals(GameEventType.gameCreated));
        expect(decoded.data['gameName'], equals('Testspil'));
        expect(decoded.data['playerIds'], equals([100, 101, 102, 103, 104]));
      });

      test('encodes and decodes spandauerKill event correctly', () {
        final event = GameEvent.spandauerKill(
          gameId: 'sp_test',
          actorId: 101,
          targetId: 102,
        );

        final encoded = SpandauerProtocol.encode(event);
        final decoded = SpandauerProtocol.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.type, equals(GameEventType.spandauerKill));
        expect(decoded.actorId, equals(101));
        expect(decoded.targetId, equals(102));
      });

      test('encodes and decodes nightStarted event correctly', () {
        final event = GameEvent.nightStarted(
          gameId: 'sp_test',
          nightNumber: 3,
        );

        final encoded = SpandauerProtocol.encode(event);
        final decoded = SpandauerProtocol.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.type, equals(GameEventType.nightStarted));
        expect(decoded.phaseNumber, equals(3));
      });

      test('encodes and decodes gameEnded event correctly', () {
        final event = GameEvent.gameEnded(
          gameId: 'sp_test',
          winningTeam: Team.villagers,
        );

        final encoded = SpandauerProtocol.encode(event);
        final decoded = SpandauerProtocol.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.type, equals(GameEventType.gameEnded));
        expect(decoded.winningTeam, equals(Team.villagers));
      });
    });

    group('isGameMessage', () {
      test('returns true for valid game message', () {
        final event = GameEvent.vote(
          gameId: 'sp_test',
          voterId: 1,
          targetId: 2,
        );
        final encoded = SpandauerProtocol.encode(event);

        expect(SpandauerProtocol.isGameMessage(encoded), isTrue);
      });

      test('returns false for normal message', () {
        expect(SpandauerProtocol.isGameMessage('Hello world'), isFalse);
        expect(SpandauerProtocol.isGameMessage(''), isFalse);
        expect(SpandauerProtocol.isGameMessage('abc123'), isFalse);
      });

      test('returns true for message starting with game prefix', () {
        expect(SpandauerProtocol.isGameMessage('🎮somethingencoded'), isTrue);
      });
    });

    group('decode error handling', () {
      test('returns null for non-game message', () {
        expect(SpandauerProtocol.decode('Not a game message'), isNull);
      });

      test('returns null for invalid base64', () {
        expect(SpandauerProtocol.decode('🎮!!!invalid!!!'), isNull);
      });

      test('returns null for invalid JSON', () {
        // Valid base64 but invalid JSON
        expect(SpandauerProtocol.decode('🎮aW52YWxpZA=='), isNull);
      });
    });

    group('extractGameId', () {
      test('extracts game ID from encoded message', () {
        final event = GameEvent.vote(
          gameId: 'sp_myuniqueid',
          voterId: 1,
          targetId: 2,
        );
        final encoded = SpandauerProtocol.encode(event);

        expect(SpandauerProtocol.extractGameId(encoded), equals('sp_myuniqueid'));
      });

      test('returns null for non-game message', () {
        expect(SpandauerProtocol.extractGameId('Hello'), isNull);
      });

      test('returns null for invalid encoded message', () {
        expect(SpandauerProtocol.extractGameId('🎮invalid'), isNull);
      });
    });

    group('generateGameId', () {
      test('generates unique IDs', () {
        final id1 = SpandauerProtocol.generateGameId();
        final id2 = SpandauerProtocol.generateGameId();

        expect(id1, isNot(equals(id2)));
      });

      test('generates ID with correct prefix', () {
        final id = SpandauerProtocol.generateGameId();

        expect(id, startsWith('sp_'));
      });
    });

    group('encoded message format', () {
      test('encoded message starts with game prefix emoji', () {
        final event = GameEvent.vote(
          gameId: 'sp_test',
          voterId: 1,
          targetId: 2,
        );
        final encoded = SpandauerProtocol.encode(event);

        expect(encoded, startsWith('🎮'));
      });

      test('timestamp is preserved in roundtrip', () {
        final timestamp = DateTime(2024, 6, 15, 14, 30, 0);
        final event = GameEvent(
          id: 'test',
          gameId: 'sp_test',
          type: GameEventType.vote,
          data: {'targetId': 2},
          timestamp: timestamp,
          actorId: 1,
        );

        final encoded = SpandauerProtocol.encode(event);
        final decoded = SpandauerProtocol.decode(encoded);

        expect(decoded!.timestamp, equals(timestamp));
      });
    });
  });
}
