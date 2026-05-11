import 'package:flutter/material.dart';

import '../../models/models.dart';

class PlayerCircle extends StatelessWidget {
  final List<GamePlayer> players;
  final int currentUserId;
  final Role? myRole;
  final Map<int, int> currentVotes;
  final bool isNight;
  final bool isDay;

  const PlayerCircle({
    super.key,
    required this.players,
    required this.currentUserId,
    this.myRole,
    this.currentVotes = const {},
    this.isNight = false,
    this.isDay = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alivePlayers = players.where((p) => p.isAlive).toList();
    final deadPlayers = players.where((p) => p.isDead).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alive players in a grid
        Text(
          'I live',
          style: theme.textTheme.titleSmall?.copyWith(
            color: isNight ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: alivePlayers.map((player) {
            return _PlayerTile(
              player: player,
              isCurrentUser: player.id == currentUserId,
              myRole: myRole,
              votesReceived: _countVotes(player.id),
              hasVoted: currentVotes.containsKey(player.id),
              isNight: isNight,
              showRole: _shouldShowRole(player),
            );
          }).toList(),
        ),

        // Dead players
        if (deadPlayers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Døde',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isNight ? Colors.white38 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: deadPlayers.map((player) {
              return _PlayerTile(
                player: player,
                isCurrentUser: player.id == currentUserId,
                myRole: myRole,
                votesReceived: 0,
                hasVoted: false,
                isNight: isNight,
                showRole: true, // Always show dead players' roles
                isDead: true,
              );
            }).toList(),
          ),
        ],

        // Vote summary during day
        if (isDay && currentVotes.isNotEmpty) ...[
          const SizedBox(height: 24),
          _VoteSummary(
            votes: currentVotes,
            players: players,
            isNight: isNight,
          ),
        ],
      ],
    );
  }

  int _countVotes(int playerId) {
    return currentVotes.values.where((v) => v == playerId).length;
  }

  bool _shouldShowRole(GamePlayer player) {
    // Show own role
    if (player.id == currentUserId) return true;

    // Spandauers see other spandauers at night
    if (isNight && myRole == Role.spandauer && player.role == Role.spandauer) {
      return true;
    }

    return false;
  }
}

class _PlayerTile extends StatelessWidget {
  final GamePlayer player;
  final bool isCurrentUser;
  final Role? myRole;
  final int votesReceived;
  final bool hasVoted;
  final bool isNight;
  final bool showRole;
  final bool isDead;

  const _PlayerTile({
    required this.player,
    required this.isCurrentUser,
    this.myRole,
    this.votesReceived = 0,
    this.hasVoted = false,
    this.isNight = false,
    this.showRole = false,
    this.isDead = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(
                color: isNight ? Colors.white : theme.colorScheme.primary,
                width: 2,
              )
            : null,
      ),
      child: Column(
        children: [
          // Avatar with role badge
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDead
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primaryContainer,
                child: Text(
                  player.name.isNotEmpty ? player.name[0] : '?',
                  style: TextStyle(
                    fontSize: 20,
                    color: isDead
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (showRole && player.role != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF1a237e) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNight ? Colors.white24 : theme.colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      player.role!.emoji,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              if (isDead)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('💀', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            isCurrentUser ? 'Dig' : player.name.split(' ').first,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isCurrentUser ? FontWeight.bold : null,
              color: isNight ? Colors.white : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Vote count
          if (votesReceived > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$votesReceived 🗳️',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          // Has voted indicator
          if (hasVoted) ...[
            const SizedBox(height: 4),
            const Text('✓', style: TextStyle(color: Colors.green)),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (isDead) {
      return isNight
          ? Colors.white.withValues(alpha: 0.05)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    }
    return isNight
        ? Colors.white.withValues(alpha: 0.1)
        : theme.colorScheme.surfaceContainerHighest;
  }
}

class _VoteSummary extends StatelessWidget {
  final Map<int, int> votes;
  final List<GamePlayer> players;
  final bool isNight;

  const _VoteSummary({
    required this.votes,
    required this.players,
    required this.isNight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Count votes per target
    final voteCounts = <int, int>{};
    for (final targetId in votes.values) {
      voteCounts[targetId] = (voteCounts[targetId] ?? 0) + 1;
    }

    // Sort by vote count
    final sortedTargets = voteCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: isNight
          ? Colors.white.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Afstemning',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isNight ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 12),
            ...sortedTargets.map((entry) {
              final player = players.firstWhere(
                (p) => p.id == entry.key,
                orElse: () => GamePlayer(id: entry.key, name: 'Ukendt'),
              );
              final totalVoters = players.where((p) => p.isAlive).length;
              final percentage = (entry.value / totalVoters * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        player.name.isNotEmpty ? player.name[0] : '?',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: TextStyle(
                              color: isNight ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: entry.value / totalVoters,
                            backgroundColor: isNight
                                ? Colors.white24
                                : theme.colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${entry.value} ($percentage%)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isNight ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
