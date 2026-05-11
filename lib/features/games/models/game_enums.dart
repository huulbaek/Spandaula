/// Game phase states
enum GamePhase {
  /// Waiting for players to join
  lobby,

  /// Night phase - wolves hunt, seer investigates
  night,

  /// Day phase - discussion and voting
  day,

  /// Game has ended
  ended,
}

/// Player roles in Spandauer (the game)
enum Role {
  /// Regular villager - votes during day
  villager,

  /// Spandauer - kills at night, pretends to be villager
  spandauer,

  /// Seer - can investigate one player each night
  seer,

  /// Healer - can protect one player each night
  healer,

  /// Hunter - when killed, can take someone with them
  hunter,
}

/// Team affiliations
enum Team {
  /// Villagers win when all spandauers are eliminated
  villagers,

  /// Spandauers win when they equal or outnumber villagers
  spandauers,
}

/// Player status
enum PlayerStatus {
  alive,
  dead,
}

/// Game event types
enum GameEventType {
  // Setup events
  gameCreated,
  playerJoined,
  gameStarted,
  rolesAssigned,

  // Phase transitions
  nightStarted,
  dayStarted,

  // Night actions
  spandauerKill,
  seerInvestigate,
  seerResult,
  healerProtect,

  // Day actions
  vote,
  voteResult,

  // Death events
  playerKilled,
  playerLynched,
  hunterRevenge,

  // End game
  gameEnded,
}

extension RoleExtension on Role {
  String get danishName {
    switch (this) {
      case Role.villager:
        return 'Landsbyboer';
      case Role.spandauer:
        return 'Spandauer';
      case Role.seer:
        return 'Seer';
      case Role.healer:
        return 'Heler';
      case Role.hunter:
        return 'Jæger';
    }
  }

  String get danishDescription {
    switch (this) {
      case Role.villager:
        return 'Find og stem spandauerne ud af landsbyen.';
      case Role.spandauer:
        return 'Spis landsbyboerne om natten uden at blive opdaget.';
      case Role.seer:
        return 'Undersøg én spiller hver nat for at finde spandauerne.';
      case Role.healer:
        return 'Beskyt én spiller hver nat mod spandauernes angreb.';
      case Role.hunter:
        return 'Når du dør, kan du tage én spiller med dig i graven.';
    }
  }

  Team get team {
    switch (this) {
      case Role.spandauer:
        return Team.spandauers;
      default:
        return Team.villagers;
    }
  }

  String get emoji {
    switch (this) {
      case Role.villager:
        return '👨‍🌾';
      case Role.spandauer:
        return '🥐';
      case Role.seer:
        return '👁️';
      case Role.healer:
        return '💚';
      case Role.hunter:
        return '🏹';
    }
  }
}

extension GamePhaseExtension on GamePhase {
  String get danishName {
    switch (this) {
      case GamePhase.lobby:
        return 'Venter';
      case GamePhase.night:
        return 'Nat';
      case GamePhase.day:
        return 'Dag';
      case GamePhase.ended:
        return 'Slut';
    }
  }

  String get emoji {
    switch (this) {
      case GamePhase.lobby:
        return '⏳';
      case GamePhase.night:
        return '🌙';
      case GamePhase.day:
        return '☀️';
      case GamePhase.ended:
        return '🏁';
    }
  }
}

extension TeamExtension on Team {
  String get danishName {
    switch (this) {
      case Team.villagers:
        return 'Landsbyboerne';
      case Team.spandauers:
        return 'Spandauerne';
    }
  }
}
