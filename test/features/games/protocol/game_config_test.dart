import 'package:flutter_test/flutter_test.dart';
import 'package:spandaula/features/games/protocol/protocol.dart';

void main() {
  group('GameConfig', () {
    group('recommended factory', () {
      test('5 players: 1 spandauer, seer only', () {
        final config = GameConfig.recommended(5);

        expect(config.spandauerCount, equals(1));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isFalse);
        expect(config.includeHunter, isFalse);
      });

      test('6 players: 1 spandauer, seer only', () {
        final config = GameConfig.recommended(6);

        expect(config.spandauerCount, equals(1));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isFalse);
        expect(config.includeHunter, isFalse);
      });

      test('7 players: 2 spandauers, seer + healer', () {
        final config = GameConfig.recommended(7);

        expect(config.spandauerCount, equals(2));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isTrue);
        expect(config.includeHunter, isFalse);
      });

      test('8 players: 2 spandauers, seer + healer', () {
        final config = GameConfig.recommended(8);

        expect(config.spandauerCount, equals(2));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isTrue);
        expect(config.includeHunter, isFalse);
      });

      test('9 players: 2 spandauers, all special roles', () {
        final config = GameConfig.recommended(9);

        expect(config.spandauerCount, equals(2));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isTrue);
        expect(config.includeHunter, isTrue);
      });

      test('10 players: 2 spandauers, all special roles', () {
        final config = GameConfig.recommended(10);

        expect(config.spandauerCount, equals(2));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isTrue);
        expect(config.includeHunter, isTrue);
      });

      test('11 players: 3 spandauers, all special roles', () {
        final config = GameConfig.recommended(11);

        expect(config.spandauerCount, equals(3));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isTrue);
        expect(config.includeHunter, isTrue);
      });

      test('15 players: 3 spandauers, all special roles', () {
        final config = GameConfig.recommended(15);

        expect(config.spandauerCount, equals(3));
        expect(config.includeSeer, isTrue);
        expect(config.includeHealer, isTrue);
        expect(config.includeHunter, isTrue);
      });
    });

    group('minPlayers', () {
      test('basic config: spandauer + 1 villager', () {
        const config = GameConfig(
          spandauerCount: 1,
          includeSeer: false,
          includeHealer: false,
          includeHunter: false,
        );

        // 1 spandauer + 1 villager minimum
        expect(config.minPlayers, equals(2));
      });

      test('config with seer', () {
        const config = GameConfig(
          spandauerCount: 1,
          includeSeer: true,
          includeHealer: false,
          includeHunter: false,
        );

        // 1 spandauer + 1 seer + 1 villager
        expect(config.minPlayers, equals(3));
      });

      test('config with seer and healer', () {
        const config = GameConfig(
          spandauerCount: 2,
          includeSeer: true,
          includeHealer: true,
          includeHunter: false,
        );

        // 2 spandauers + 1 seer + 1 healer + 1 villager
        expect(config.minPlayers, equals(5));
      });

      test('config with all special roles', () {
        const config = GameConfig(
          spandauerCount: 2,
          includeSeer: true,
          includeHealer: true,
          includeHunter: true,
        );

        // 2 spandauers + 1 seer + 1 healer + 1 hunter + 1 villager
        expect(config.minPlayers, equals(6));
      });

      test('large config', () {
        const config = GameConfig(
          spandauerCount: 3,
          includeSeer: true,
          includeHealer: true,
          includeHunter: true,
        );

        // 3 spandauers + 3 special + 1 villager
        expect(config.minPlayers, equals(7));
      });
    });

    group('constructor defaults', () {
      test('seer defaults to true', () {
        const config = GameConfig(spandauerCount: 1);
        expect(config.includeSeer, isTrue);
      });

      test('healer defaults to false', () {
        const config = GameConfig(spandauerCount: 1);
        expect(config.includeHealer, isFalse);
      });

      test('hunter defaults to false', () {
        const config = GameConfig(spandauerCount: 1);
        expect(config.includeHunter, isFalse);
      });
    });
  });
}
