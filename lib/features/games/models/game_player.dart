import 'game_enums.dart';

/// A player in a Spandauer game
class GamePlayer {
  /// Aula profile ID
  final int id;

  /// Player's display name
  final String name;

  /// Profile picture URL
  final String? profilePicture;

  /// Player's role (only visible to the player themselves or after death)
  final Role? role;

  /// Whether player is alive or dead
  final PlayerStatus status;

  /// Whether this player has completed their night action (if applicable)
  final bool hasActedThisPhase;

  const GamePlayer({
    required this.id,
    required this.name,
    this.profilePicture,
    this.role,
    this.status = PlayerStatus.alive,
    this.hasActedThisPhase = false,
  });

  bool get isAlive => status == PlayerStatus.alive;
  bool get isDead => status == PlayerStatus.dead;

  /// Check if this player is on the spandauer team
  bool get isSpandauer => role == Role.spandauer;

  GamePlayer copyWith({
    int? id,
    String? name,
    String? profilePicture,
    Role? role,
    PlayerStatus? status,
    bool? hasActedThisPhase,
  }) {
    return GamePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      profilePicture: profilePicture ?? this.profilePicture,
      role: role ?? this.role,
      status: status ?? this.status,
      hasActedThisPhase: hasActedThisPhase ?? this.hasActedThisPhase,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profilePicture': profilePicture,
        'role': role?.name,
        'status': status.name,
        'hasActedThisPhase': hasActedThisPhase,
      };

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    return GamePlayer(
      id: json['id'] as int,
      name: json['name'] as String,
      profilePicture: json['profilePicture'] as String?,
      role: json['role'] != null
          ? Role.values.firstWhere((r) => r.name == json['role'])
          : null,
      status: json['status'] != null
          ? PlayerStatus.values.firstWhere((s) => s.name == json['status'])
          : PlayerStatus.alive,
      hasActedThisPhase: json['hasActedThisPhase'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamePlayer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
