import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';

class GameLog extends StatelessWidget {
  final List<GameEvent> events;
  final List<GamePlayer> players;

  const GameLog({
    super.key,
    required this.events,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (events.isEmpty) {
      return Center(
        child: Text(
          'Ingen begivenheder endnu',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Filter to only show public events
    final publicEvents = events.where(_isPublicEvent).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: publicEvents.length,
      itemBuilder: (context, index) {
        final event = publicEvents[publicEvents.length - 1 - index]; // Reverse order
        return _EventTile(
          event: event,
          players: players,
        );
      },
    );
  }

  bool _isPublicEvent(GameEvent event) {
    switch (event.type) {
      // Public events
      case GameEventType.gameCreated:
      case GameEventType.gameStarted:
      case GameEventType.nightStarted:
      case GameEventType.dayStarted:
      case GameEventType.vote:
      case GameEventType.voteResult:
      case GameEventType.playerKilled:
      case GameEventType.playerLynched:
      case GameEventType.gameEnded:
        return true;

      // Private events
      case GameEventType.rolesAssigned:
      case GameEventType.spandauerKill:
      case GameEventType.seerInvestigate:
      case GameEventType.seerResult:
      case GameEventType.healerProtect:
      case GameEventType.hunterRevenge:
      case GameEventType.playerJoined:
        return false;
    }
  }
}

class _EventTile extends StatelessWidget {
  final GameEvent event;
  final List<GamePlayer> players;

  const _EventTile({
    required this.event,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm', 'da_DK');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getEventColor(theme).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getEventEmoji(),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getEventTitle(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_getEventDescription().isNotEmpty)
                  Text(
                    _getEventDescription(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Timestamp
          Text(
            timeFormat.format(event.timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getEventEmoji() {
    switch (event.type) {
      case GameEventType.gameCreated:
        return '🎮';
      case GameEventType.gameStarted:
        return '▶️';
      case GameEventType.nightStarted:
        return '🌙';
      case GameEventType.dayStarted:
        return '☀️';
      case GameEventType.vote:
        return '🗳️';
      case GameEventType.voteResult:
        return '📊';
      case GameEventType.playerKilled:
        return '💀';
      case GameEventType.playerLynched:
        return '⚖️';
      case GameEventType.gameEnded:
        return '🏆';
      default:
        return '📝';
    }
  }

  Color _getEventColor(ThemeData theme) {
    switch (event.type) {
      case GameEventType.nightStarted:
        return const Color(0xFF1a237e);
      case GameEventType.dayStarted:
        return Colors.orange;
      case GameEventType.playerKilled:
      case GameEventType.playerLynched:
        return Colors.red;
      case GameEventType.gameEnded:
        return Colors.green;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _getEventTitle() {
    switch (event.type) {
      case GameEventType.gameCreated:
        return 'Spillet er oprettet';
      case GameEventType.gameStarted:
        return 'Spillet er startet';
      case GameEventType.nightStarted:
        return 'Nat ${event.phaseNumber ?? ""}';
      case GameEventType.dayStarted:
        return 'Dag ${event.phaseNumber ?? ""}';
      case GameEventType.vote:
        final voter = _getPlayerName(event.actorId);
        final target = _getPlayerName(event.targetId);
        return '$voter stemte på $target';
      case GameEventType.playerKilled:
        final victim = _getPlayerName(event.victimId);
        return '$victim blev dræbt i nat';
      case GameEventType.playerLynched:
        final victim = _getPlayerName(event.victimId);
        return '$victim blev stemt ud';
      case GameEventType.gameEnded:
        final winner = event.winningTeam;
        return winner != null ? '${winner.danishName} vandt!' : 'Spillet er slut';
      default:
        return event.type.name;
    }
  }

  String _getEventDescription() {
    switch (event.type) {
      case GameEventType.nightStarted:
        return 'Landsbyen sover...';
      case GameEventType.dayStarted:
        final killedId = event.data['killedPlayerId'] as int?;
        if (killedId != null) {
          final victim = _getPlayerName(killedId);
          return '$victim blev fundet død.';
        }
        return 'Ingen døde i nat.';
      case GameEventType.playerLynched:
        final victim = players.firstWhere(
          (p) => p.id == event.victimId,
          orElse: () => GamePlayer(id: 0, name: 'Ukendt'),
        );
        if (victim.role != null) {
          return '${victim.name} var ${victim.role!.danishName}';
        }
        return '';
      case GameEventType.playerKilled:
        final victim = players.firstWhere(
          (p) => p.id == event.victimId,
          orElse: () => GamePlayer(id: 0, name: 'Ukendt'),
        );
        if (victim.role != null) {
          return '${victim.name} var ${victim.role!.danishName}';
        }
        return '';
      default:
        return '';
    }
  }

  String _getPlayerName(int? playerId) {
    if (playerId == null) return 'Ukendt';
    final player = players.firstWhere(
      (p) => p.id == playerId,
      orElse: () => GamePlayer(id: playerId, name: 'Spiller $playerId'),
    );
    return player.name;
  }
}
