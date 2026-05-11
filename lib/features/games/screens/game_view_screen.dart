import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_spinner.dart';
import '../../auth/auth_provider.dart';
import '../models/models.dart';
import '../providers/games_provider.dart';
import 'widgets/action_panel.dart';
import 'widgets/game_log.dart';
import 'widgets/player_circle.dart';
import 'widgets/role_card.dart';

class GameViewScreen extends ConsumerStatefulWidget {
  final String gameId;
  final int threadId;

  const GameViewScreen({
    super.key,
    required this.gameId,
    required this.threadId,
  });

  @override
  ConsumerState<GameViewScreen> createState() => _GameViewScreenState();
}

class _GameViewScreenState extends ConsumerState<GameViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load game data
    Future.microtask(() {
      ref
          .read(gameDetailProvider((
            gameId: widget.gameId,
            threadId: widget.threadId,
          )).notifier)
          .loadGame();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameState = ref.watch(gameDetailProvider((
      gameId: widget.gameId,
      threadId: widget.threadId,
    )));
    final profile = ref.watch(currentProfileProvider);
    final currentUserId = profile?.id ?? 0;

    return Scaffold(
      backgroundColor: _getBackgroundColor(gameState.game, theme),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(gameState.game?.name ?? 'Spandauer'),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
            onPressed: () => ref
                .read(gameDetailProvider((
                  gameId: widget.gameId,
                  threadId: widget.threadId,
                )).notifier)
                .refresh(),
          ),
        ],
      ),
      body: gameState.isLoading && gameState.game == null
          ? const Center(child: AppSpinner())
          : gameState.error != null && gameState.game == null
              ? _buildError(gameState.error!, theme)
              : gameState.game != null
                  ? _buildGame(gameState, currentUserId, theme)
                  : _buildError('Spil ikke fundet', theme),
    );
  }

  Color _getBackgroundColor(SpandauerGame? game, ThemeData theme) {
    if (game == null) return theme.colorScheme.surface;

    switch (game.phase) {
      case GamePhase.night:
        return const Color(0xFF0d1b2a); // Dark blue
      case GamePhase.day:
        return theme.colorScheme.surface;
      default:
        return theme.colorScheme.surface;
    }
  }

  Widget _buildError(String error, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedAlertCircle, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref
                .read(gameDetailProvider((
                  gameId: widget.gameId,
                  threadId: widget.threadId,
                )).notifier)
                .refresh(),
            child: const Text('Prøv igen'),
          ),
        ],
      ),
    );
  }

  Widget _buildGame(
    GameDetailState state,
    int currentUserId,
    ThemeData theme,
  ) {
    final game = state.game!;
    final myRole = state.myRole;
    final isNight = game.phase == GamePhase.night;

    return Column(
      children: [
        // Phase header
        _buildPhaseHeader(game, theme, isNight),

        // Role card (always visible)
        if (myRole != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RoleCard(
              role: myRole,
              isNight: isNight,
              isAlive: game.getPlayer(currentUserId)?.isAlive ?? false,
            ),
          ),

        const SizedBox(height: 16),

        // Tab bar
        TabBar(
          controller: _tabController,
          labelColor: isNight ? Colors.white : theme.colorScheme.primary,
          unselectedLabelColor:
              isNight ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
          indicatorColor: isNight ? Colors.white : theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Spillere'),
            Tab(text: 'Log'),
          ],
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Players tab
              _buildPlayersTab(game, currentUserId, myRole, theme, isNight),
              // Log tab
              GameLog(events: game.events, players: game.players),
            ],
          ),
        ),

        // Action panel at bottom
        if (!game.isEnded && game.needsAction(currentUserId))
          SafeArea(
            child: ActionPanel(
              game: game,
              currentUserId: currentUserId,
              myRole: myRole,
              onAction: (targetId) => _submitAction(game, currentUserId, myRole, targetId),
            ),
          ),
      ],
    );
  }

  Widget _buildPhaseHeader(SpandauerGame game, ThemeData theme, bool isNight) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            game.phase.emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${game.phase.danishName} ${game.phaseNumber}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isNight ? Colors.white : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${game.alivePlayers.length} i live, ${game.deadPlayers.length} døde',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isNight ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersTab(
    SpandauerGame game,
    int currentUserId,
    Role? myRole,
    ThemeData theme,
    bool isNight,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PlayerCircle(
        players: game.players,
        currentUserId: currentUserId,
        myRole: myRole,
        currentVotes: game.currentVotes,
        isNight: isNight,
        isDay: game.isDay,
      ),
    );
  }

  Future<void> _submitAction(
    SpandauerGame game,
    int currentUserId,
    Role? myRole,
    int targetId,
  ) async {
    final notifier = ref.read(gameDetailProvider((
      gameId: widget.gameId,
      threadId: widget.threadId,
    )).notifier);

    bool success = false;

    if (game.isDay) {
      success = await notifier.vote(targetId);
    } else if (game.isNight && myRole != null) {
      switch (myRole) {
        case Role.spandauer:
          success = await notifier.spandauerKill(targetId);
          break;
        case Role.seer:
          success = await notifier.seerInvestigate(targetId);
          break;
        case Role.healer:
          success = await notifier.healerProtect(targetId);
          break;
        default:
          break;
      }
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Handling registreret')),
      );
    }
  }
}
