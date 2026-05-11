import 'dart:convert';
import 'dart:math';

import '../models/models.dart';

/// Simple encryption for role assignments
///
/// Each player's role is encrypted using their player ID + game salt
/// so that only they can decrypt their own role. This isn't cryptographically
/// secure, but it's sufficient to prevent casual inspection.
class RoleEncryption {
  /// Encrypt a role for a specific player
  static String encryptRole(Role role, int playerId, String gameSalt) {
    final key = _deriveKey(playerId, gameSalt);
    final roleBytes = utf8.encode(role.name);

    // XOR encryption with key
    final encrypted = <int>[];
    for (var i = 0; i < roleBytes.length; i++) {
      encrypted.add(roleBytes[i] ^ key[i % key.length]);
    }

    return base64Encode(encrypted);
  }

  /// Decrypt a role for a specific player
  static Role? decryptRole(String encrypted, int playerId, String gameSalt) {
    try {
      final key = _deriveKey(playerId, gameSalt);
      final encryptedBytes = base64Decode(encrypted);

      // XOR decryption with key
      final decrypted = <int>[];
      for (var i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ key[i % key.length]);
      }

      final roleName = utf8.decode(decrypted);
      return Role.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => throw FormatException('Unknown role: $roleName'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Derive an encryption key from player ID and game salt
  static List<int> _deriveKey(int playerId, String gameSalt) {
    // Simple key derivation: combine player ID and salt, then hash-like transform
    final combined = '$playerId:$gameSalt';
    final bytes = utf8.encode(combined);

    // Simple mixing function
    final key = List<int>.filled(16, 0);
    for (var i = 0; i < bytes.length; i++) {
      key[i % 16] = (key[i % 16] + bytes[i] * (i + 1)) % 256;
    }

    return key;
  }

  /// Generate a random game salt
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Create encrypted role assignments for all players
  static Map<String, String> encryptRoles(
    Map<int, Role> assignments,
    String gameSalt,
  ) {
    return assignments.map(
      (playerId, role) => MapEntry(
        playerId.toString(),
        encryptRole(role, playerId, gameSalt),
      ),
    );
  }

  /// Assign roles to players randomly
  static Map<int, Role> assignRoles(List<int> playerIds, GameConfig config) {
    final roles = <Role>[];

    // Add spandauers
    for (var i = 0; i < config.spandauerCount; i++) {
      roles.add(Role.spandauer);
    }

    // Add special roles
    if (config.includeSeer) roles.add(Role.seer);
    if (config.includeHealer) roles.add(Role.healer);
    if (config.includeHunter) roles.add(Role.hunter);

    // Fill remaining with villagers
    while (roles.length < playerIds.length) {
      roles.add(Role.villager);
    }

    // Shuffle roles
    roles.shuffle(Random.secure());

    // Assign to players
    final assignments = <int, Role>{};
    for (var i = 0; i < playerIds.length; i++) {
      assignments[playerIds[i]] = roles[i];
    }

    return assignments;
  }
}

/// Game configuration for role distribution
class GameConfig {
  /// Number of spandauers
  final int spandauerCount;

  /// Include the Seer role
  final bool includeSeer;

  /// Include the Healer role
  final bool includeHealer;

  /// Include the Hunter role
  final bool includeHunter;

  const GameConfig({
    required this.spandauerCount,
    this.includeSeer = true,
    this.includeHealer = false,
    this.includeHunter = false,
  });

  /// Get recommended config for a player count
  factory GameConfig.recommended(int playerCount) {
    // Recommended ratios:
    // 5-6 players: 1 spandauer, seer only
    // 7-8 players: 2 spandauers, seer + healer
    // 9-10 players: 2 spandauers, seer + healer + hunter
    // 11+ players: 3 spandauers, all special roles

    if (playerCount <= 6) {
      return const GameConfig(
        spandauerCount: 1,
        includeSeer: true,
        includeHealer: false,
        includeHunter: false,
      );
    } else if (playerCount <= 8) {
      return const GameConfig(
        spandauerCount: 2,
        includeSeer: true,
        includeHealer: true,
        includeHunter: false,
      );
    } else if (playerCount <= 10) {
      return const GameConfig(
        spandauerCount: 2,
        includeSeer: true,
        includeHealer: true,
        includeHunter: true,
      );
    } else {
      return const GameConfig(
        spandauerCount: 3,
        includeSeer: true,
        includeHealer: true,
        includeHunter: true,
      );
    }
  }

  /// Minimum players needed for this config
  int get minPlayers => spandauerCount + (includeSeer ? 1 : 0) + (includeHealer ? 1 : 0) + (includeHunter ? 1 : 0) + 1;
}
