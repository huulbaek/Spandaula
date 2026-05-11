import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_spinner.dart';
import '../models/models.dart';
import '../providers/games_provider.dart';
import 'create_game_screen.dart';
import 'game_view_screen.dart';

class GamesListScreen extends ConsumerStatefulWidget {
  const GamesListScreen({super.key});

  @override
  ConsumerState<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends ConsumerState<GamesListScreen> {
  @override
  void initState() {
    super.initState();
    // Load games on first load
    Future.microtask(() {
      ref.read(gamesProvider.notifier).scanForGames();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gamesState = ref.watch(gamesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spil'),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
            onPressed: () => ref.read(gamesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(gamesProvider.notifier).refresh(),
        child: _buildBody(gamesState, theme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_game_fab',
        onPressed: () => _showCreateGameOptions(context),
        icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
        label: const Text('Nyt spil'),
      ),
    );
  }

  Widget _buildBody(GamesState state, ThemeData theme) {
    if (state.isLoading && state.games.isEmpty) {
      return const Center(child: AppSpinner());
    }

    if (state.error != null && state.games.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedAlertCircle,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Fejl: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(gamesProvider.notifier).refresh(),
              child: const Text('Prøv igen'),
            ),
          ],
        ),
      );
    }

    if (state.games.isEmpty) {
      return _buildEmptyState(theme);
    }

    return CustomScrollView(
      slivers: [
        // Games needing action
        if (state.gamesNeedingAction.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Din tur',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final game = state.gamesNeedingAction[index];
                return _GameCard(
                  game: game,
                  needsAction: true,
                  onTap: () => _openGame(game),
                );
              },
              childCount: state.gamesNeedingAction.length,
            ),
          ),
        ],

        // Other active games
        if (state.activeGames
            .where((g) => !state.gamesNeedingAction.contains(g))
            .isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Aktive spil',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final otherGames = state.activeGames
                    .where((g) => !state.gamesNeedingAction.contains(g))
                    .toList();
                final game = otherGames[index];
                return _GameCard(
                  game: game,
                  needsAction: false,
                  onTap: () => _openGame(game),
                );
              },
              childCount: state.activeGames
                  .where((g) => !state.gamesNeedingAction.contains(g))
                  .length,
            ),
          ),
        ],

        // Ended games
        if (state.endedGames.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Afsluttede spil',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final game = state.endedGames[index];
                return _GameCard(
                  game: game,
                  needsAction: false,
                  onTap: () => _openGame(game),
                );
              },
              childCount: state.endedGames.length,
            ),
          ),
        ],

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🥐',
              style: theme.textTheme.displayLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Ingen spil endnu',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start et nyt Spandauer-spil med dine venner!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showCreateGameOptions(context),
              icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
              label: const Text('Start nyt spil'),
            ),
          ],
        ),
      ),
    );
  }

  void _openGame(SpandauerGame game) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameViewScreen(gameId: game.id, threadId: game.threadId),
      ),
    );
  }

  void _showCreateGameOptions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateGameScreen()),
    );
  }
}

class _GameCard extends StatelessWidget {
  final SpandauerGame game;
  final bool needsAction;
  final VoidCallback onTap;

  const _GameCard({
    required this.game,
    required this.needsAction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Phase indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getPhaseColor(theme),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    game.phase.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (needsAction)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Din tur',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Player avatars
                    Row(
                      children: [
                        ...game.alivePlayers.take(5).map((p) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  p.name.isNotEmpty ? p.name[0] : '?',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            )),
                        if (game.alivePlayers.length > 5)
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            child: Text(
                              '+${game.alivePlayers.length - 5}',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPhaseColor(ThemeData theme) {
    switch (game.phase) {
      case GamePhase.lobby:
        return theme.colorScheme.surfaceContainerHighest;
      case GamePhase.night:
        return const Color(0xFF1a237e); // Dark blue
      case GamePhase.day:
        return const Color(0xFFfff8e1); // Light yellow
      case GamePhase.ended:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  String _getStatusText() {
    if (game.isEnded) {
      final winner = game.winner;
      if (winner != null) {
        return '${winner.danishName} vandt!';
      }
      return 'Spillet er slut';
    }

    final alive = game.alivePlayers.length;
    final dead = game.deadPlayers.length;

    if (game.isNight) {
      return 'Nat ${game.phaseNumber} - $alive i live, $dead døde';
    } else if (game.isDay) {
      return 'Dag ${game.phaseNumber} - $alive i live, $dead døde';
    } else {
      return '${game.players.length} spillere';
    }
  }
}
