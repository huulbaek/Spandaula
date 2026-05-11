import 'package:flutter/material.dart';

import '../../models/models.dart';

class RoleCard extends StatelessWidget {
  final Role role;
  final bool isNight;
  final bool isAlive;

  const RoleCard({
    super.key,
    required this.role,
    required this.isNight,
    required this.isAlive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isNight
          ? const Color(0xFF1a237e).withValues(alpha: 0.9)
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Role emoji
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isNight
                    ? Colors.white.withValues(alpha: 0.1)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  role.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Role info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Du er ${role.danishName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isNight
                              ? Colors.white
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (!isAlive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DØD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.danishDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isNight
                          ? Colors.white70
                          : theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Team indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: role.team == Team.spandauers
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                role.team == Team.spandauers ? '🥐' : '🏠',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
