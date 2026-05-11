import 'package:flutter_test/flutter_test.dart';
import 'package:spandaula/features/games/models/models.dart';
import 'package:spandaula/features/games/protocol/protocol.dart';

void main() {
  group('RoleEncryption', () {
    const testSalt = 'dGVzdHNhbHQxMjM0NTY=';

    group('encryptRole/decryptRole roundtrip', () {
      test('roundtrips villager role correctly', () {
        const playerId = 101;
        final encrypted = RoleEncryption.encryptRole(Role.villager, playerId, testSalt);
        final decrypted = RoleEncryption.decryptRole(encrypted, playerId, testSalt);

        expect(decrypted, equals(Role.villager));
      });

      test('roundtrips spandauer role correctly', () {
        const playerId = 102;
        final encrypted = RoleEncryption.encryptRole(Role.spandauer, playerId, testSalt);
        final decrypted = RoleEncryption.decryptRole(encrypted, playerId, testSalt);

        expect(decrypted, equals(Role.spandauer));
      });

      test('roundtrips seer role correctly', () {
        const playerId = 103;
        final encrypted = RoleEncryption.encryptRole(Role.seer, playerId, testSalt);
        final decrypted = RoleEncryption.decryptRole(encrypted, playerId, testSalt);

        expect(decrypted, equals(Role.seer));
      });

      test('roundtrips healer role correctly', () {
        const playerId = 104;
        final encrypted = RoleEncryption.encryptRole(Role.healer, playerId, testSalt);
        final decrypted = RoleEncryption.decryptRole(encrypted, playerId, testSalt);

        expect(decrypted, equals(Role.healer));
      });

      test('roundtrips hunter role correctly', () {
        const playerId = 105;
        final encrypted = RoleEncryption.encryptRole(Role.hunter, playerId, testSalt);
        final decrypted = RoleEncryption.decryptRole(encrypted, playerId, testSalt);

        expect(decrypted, equals(Role.hunter));
      });
    });

    group('encryption properties', () {
      test('different players get different encrypted values', () {
        final encrypted1 = RoleEncryption.encryptRole(Role.villager, 101, testSalt);
        final encrypted2 = RoleEncryption.encryptRole(Role.villager, 102, testSalt);

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('different salts produce different encrypted values', () {
        const playerId = 101;
        // Use very different salts to ensure different encryption keys
        final encrypted1 = RoleEncryption.encryptRole(Role.villager, playerId, 'abcdefghijklmnop');
        final encrypted2 = RoleEncryption.encryptRole(Role.villager, playerId, 'zyxwvutsrqponmlk');

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('wrong player ID cannot decrypt correctly', () {
        const correctPlayerId = 101;
        const wrongPlayerId = 102;
        final encrypted = RoleEncryption.encryptRole(Role.spandauer, correctPlayerId, testSalt);

        final decryptedWithWrongId = RoleEncryption.decryptRole(encrypted, wrongPlayerId, testSalt);

        // Should either return null or wrong role
        expect(decryptedWithWrongId, isNot(equals(Role.spandauer)));
      });

      test('wrong salt cannot decrypt correctly', () {
        const playerId = 101;
        final encrypted = RoleEncryption.encryptRole(Role.spandauer, playerId, 'correctSalt');

        final decryptedWithWrongSalt = RoleEncryption.decryptRole(encrypted, playerId, 'wrongSalt');

        expect(decryptedWithWrongSalt, isNot(equals(Role.spandauer)));
      });
    });

    group('decryptRole error handling', () {
      test('returns null for invalid base64', () {
        final result = RoleEncryption.decryptRole('!!!invalid!!!', 101, testSalt);
        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = RoleEncryption.decryptRole('', 101, testSalt);
        expect(result, isNull);
      });
    });

    group('generateSalt', () {
      test('generates unique salts', () {
        final salt1 = RoleEncryption.generateSalt();
        final salt2 = RoleEncryption.generateSalt();

        expect(salt1, isNot(equals(salt2)));
      });

      test('generates non-empty salt', () {
        final salt = RoleEncryption.generateSalt();
        expect(salt.isNotEmpty, isTrue);
      });
    });

    group('encryptRoles', () {
      test('encrypts all roles in map', () {
        final assignments = {
          101: Role.spandauer,
          102: Role.seer,
          103: Role.villager,
        };

        final encrypted = RoleEncryption.encryptRoles(assignments, testSalt);

        expect(encrypted.keys, containsAll(['101', '102', '103']));
        expect(encrypted.values.every((v) => v.isNotEmpty), isTrue);
      });

      test('each player can decrypt only their own role', () {
        final assignments = {
          101: Role.spandauer,
          102: Role.seer,
          103: Role.villager,
        };

        final encrypted = RoleEncryption.encryptRoles(assignments, testSalt);

        // Each player decrypts their own role correctly
        expect(
          RoleEncryption.decryptRole(encrypted['101']!, 101, testSalt),
          equals(Role.spandauer),
        );
        expect(
          RoleEncryption.decryptRole(encrypted['102']!, 102, testSalt),
          equals(Role.seer),
        );
        expect(
          RoleEncryption.decryptRole(encrypted['103']!, 103, testSalt),
          equals(Role.villager),
        );
      });
    });

    group('assignRoles', () {
      test('assigns correct number of spandauers', () {
        final config = GameConfig(spandauerCount: 2);
        final playerIds = [101, 102, 103, 104, 105, 106, 107];

        final assignments = RoleEncryption.assignRoles(playerIds, config);

        final spandauerCount = assignments.values.where((r) => r == Role.spandauer).length;
        expect(spandauerCount, equals(2));
      });

      test('includes seer when configured', () {
        final config = GameConfig(spandauerCount: 1, includeSeer: true);
        final playerIds = [101, 102, 103, 104, 105];

        final assignments = RoleEncryption.assignRoles(playerIds, config);

        final seerCount = assignments.values.where((r) => r == Role.seer).length;
        expect(seerCount, equals(1));
      });

      test('includes healer when configured', () {
        final config = GameConfig(spandauerCount: 1, includeHealer: true);
        final playerIds = [101, 102, 103, 104, 105];

        final assignments = RoleEncryption.assignRoles(playerIds, config);

        final healerCount = assignments.values.where((r) => r == Role.healer).length;
        expect(healerCount, equals(1));
      });

      test('includes hunter when configured', () {
        final config = GameConfig(spandauerCount: 1, includeHunter: true);
        final playerIds = [101, 102, 103, 104, 105];

        final assignments = RoleEncryption.assignRoles(playerIds, config);

        final hunterCount = assignments.values.where((r) => r == Role.hunter).length;
        expect(hunterCount, equals(1));
      });

      test('fills remaining slots with villagers', () {
        final config = GameConfig(spandauerCount: 1, includeSeer: true);
        final playerIds = [101, 102, 103, 104, 105];

        final assignments = RoleEncryption.assignRoles(playerIds, config);

        final villagerCount = assignments.values.where((r) => r == Role.villager).length;
        // 5 players - 1 spandauer - 1 seer = 3 villagers
        expect(villagerCount, equals(3));
      });

      test('assigns role to every player', () {
        final config = GameConfig(spandauerCount: 1);
        final playerIds = [101, 102, 103, 104, 105];

        final assignments = RoleEncryption.assignRoles(playerIds, config);

        expect(assignments.length, equals(5));
        expect(assignments.keys, containsAll(playerIds));
      });
    });
  });
}
