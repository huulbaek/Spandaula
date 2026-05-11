import 'package:flutter/material.dart';

import '../../models/models.dart';

class ActionPanel extends StatelessWidget {
  final SpandauerGame game;
  final int currentUserId;
  final Role? myRole;
  final Function(int targetId) onAction;

  const ActionPanel({
    super.key,
    required this.game,
    required this.currentUserId,
    required this.myRole,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNight = game.isNight;
    final targets = game.getValidTargets(currentUserId);

    if (targets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFF1a237e)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: isNight ? Colors.white24 : theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Action title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  _getActionEmoji(),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getActionTitle(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isNight ? Colors.white : null,
                        ),
                      ),
                      Text(
                        _getActionDescription(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isNight
                              ? Colors.white70
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Target selection
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets[index];
                return _TargetButton(
                  player: target,
                  isNight: isNight,
                  actionEmoji: _getActionEmoji(),
                  onTap: () => _confirmAction(context, target),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getActionEmoji() {
    if (game.isDay) return '🗳️';

    switch (myRole) {
      case Role.spandauer:
        return '🥐';
      case Role.seer:
        return '👁️';
      case Role.healer:
        return '💚';
      default:
        return '❓';
    }
  }

  String _getActionTitle() {
    if (game.isDay) return 'Stem på en spiller';

    switch (myRole) {
      case Role.spandauer:
        return 'Vælg dit offer';
      case Role.seer:
        return 'Undersøg en spiller';
      case Role.healer:
        return 'Beskyt en spiller';
      default:
        return 'Vent på dag';
    }
  }

  String _getActionDescription() {
    if (game.isDay) return 'Vælg hvem der skal stemmes ud';

    switch (myRole) {
      case Role.spandauer:
        return 'Vælg hvem spandauerne skal spise i nat';
      case Role.seer:
        return 'Find ud af om en spiller er spandauer';
      case Role.healer:
        return 'Beskyt en spiller mod spandauerne';
      default:
        return 'Du har ingen nathandling';
    }
  }

  void _confirmAction(BuildContext context, GamePlayer target) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                target.name.isNotEmpty ? target.name[0] : '?',
                style: TextStyle(
                  fontSize: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              target.name,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _getConfirmationText(target),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuller'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onAction(target.id);
                    },
                    child: const Text('Bekræft'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getConfirmationText(GamePlayer target) {
    if (game.isDay) {
      return 'Er du sikker på, at du vil stemme på ${target.name}?';
    }

    switch (myRole) {
      case Role.spandauer:
        return 'Er du sikker på, at spandauerne skal spise ${target.name} i nat?';
      case Role.seer:
        return 'Er du sikker på, at du vil undersøge ${target.name}?';
      case Role.healer:
        return 'Er du sikker på, at du vil beskytte ${target.name} i nat?';
      default:
        return 'Bekræft handling';
    }
  }
}

class _TargetButton extends StatelessWidget {
  final GamePlayer player;
  final bool isNight;
  final String actionEmoji;
  final VoidCallback onTap;

  const _TargetButton({
    required this.player,
    required this.isNight,
    required this.actionEmoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isNight
                ? Colors.white.withValues(alpha: 0.1)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNight ? Colors.white24 : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  player.name.isNotEmpty ? player.name[0] : '?',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                player.name.split(' ').first,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isNight ? Colors.white : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
