import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/webview_api_client.dart';
import '../../../core/demo/demo_config.dart';
import '../../../core/demo/demo_games.dart';
import '../../../core/models/models.dart';
import '../../auth/auth_provider.dart';
import '../../messages/messages_provider.dart';
import '../engine/engine.dart';
import '../models/models.dart';
import '../protocol/protocol.dart';

/// State for the games list
class GamesState {
  final List<SpandauerGame> games;
  final bool isLoading;
  final String? error;

  const GamesState({
    this.games = const [],
    this.isLoading = false,
    this.error,
  });

  GamesState copyWith({
    List<SpandauerGame>? games,
    bool? isLoading,
    String? error,
  }) {
    return GamesState(
      games: games ?? this.games,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Games where current player needs to act
  List<SpandauerGame> get gamesNeedingAction =>
      games.where((g) => !g.isEnded && !g.isLobby).toList();

  /// Active games (not ended)
  List<SpandauerGame> get activeGames =>
      games.where((g) => !g.isEnded).toList();

  /// Ended games
  List<SpandauerGame> get endedGames => games.where((g) => g.isEnded).toList();
}

/// Notifier for managing games list
class GamesNotifier extends StateNotifier<GamesState> {
  final WebViewApiClient _client;
  final int _currentUserId;
  final Ref _ref;

  GamesNotifier(this._client, this._currentUserId, this._ref)
      : super(const GamesState());

  /// Scan threads for games
  Future<void> scanForGames() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    // In demo mode, return hardcoded demo games
    if (DemoConfig.demoMode) {
      final demoGames = getDemoGames().map((game) {
        // Apply perspective to hide other players' roles
        return game.withPerspective(_currentUserId);
      }).toList();
      state = state.copyWith(games: demoGames, isLoading: false);
      return;
    }

    try {
      // Get threads from the threads provider
      final threadsState = _ref.read(threadsProvider);
      final threads = threadsState.threads;

      final games = <SpandauerGame>[];

      for (final thread in threads) {
        // Fetch messages for this thread if we haven't already
        final messagesState = _ref.read(threadDetailProvider(thread.id));
        List<Message> messages = messagesState.messages;

        // If no messages loaded, try to load them
        if (messages.isEmpty && thread.messageCount > 0) {
          try {
            final data = await _client.get(
              ApiEndpoints.getMessagesForThread,
              queryParams: {
                'threadId': thread.id,
                'page': 0,
              },
            );

            if (data is Map && data['messages'] is List) {
              messages = (data['messages'] as List)
                  .map((m) => Message.fromJson(m))
                  .toList();
            } else if (data is List) {
              messages = data.map((m) => Message.fromJson(m)).toList();
            }
          } catch (e) {
            debugPrint('Failed to load messages for thread ${thread.id}: $e');
            continue;
          }
        }

        // Check if this thread contains a game
        final game = SpandauerEngine.fromThread(
          thread,
          messages,
          _currentUserId,
        );

        if (game != null) {
          // Enrich player names from thread participants
          final enrichedGame = _enrichPlayerNames(game, thread);
          games.add(enrichedGame);
        }
      }

      // Sort: games needing action first, then by recent activity
      games.sort((a, b) {
        final aNeeds = a.needsAction(_currentUserId) ? 0 : 1;
        final bNeeds = b.needsAction(_currentUserId) ? 0 : 1;
        if (aNeeds != bNeeds) return aNeeds.compareTo(bNeeds);

        // Then by most recent event
        final aLatest =
            a.events.isNotEmpty ? a.events.last.timestamp : DateTime(2000);
        final bLatest =
            b.events.isNotEmpty ? b.events.last.timestamp : DateTime(2000);
        return bLatest.compareTo(aLatest);
      });

      state = state.copyWith(games: games, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Enrich player names from thread participants
  SpandauerGame _enrichPlayerNames(SpandauerGame game, Thread thread) {
    final enrichedPlayers = game.players.map((player) {
      final participant = thread.participants.firstWhere(
        (p) => p.id == player.id,
        orElse: () => ThreadParticipant(id: player.id, name: player.name),
      );
      return player.copyWith(
        name: participant.name,
        profilePicture: participant.profilePicture,
      );
    }).toList();

    return game.copyWith(players: enrichedPlayers);
  }

  /// Refresh games list
  Future<void> refresh() async {
    // First refresh threads
    await _ref.read(threadsProvider.notifier).refresh();
    // Then scan for games
    await scanForGames();
  }
}

/// Games list provider
final gamesProvider = StateNotifierProvider<GamesNotifier, GamesState>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final currentUserId = profile?.id ?? 0;
  return GamesNotifier(client, currentUserId, ref);
});

/// Single game state
class GameDetailState {
  final SpandauerGame? game;
  final bool isLoading;
  final String? error;
  final Role? myRole; // Decrypted role for current player

  const GameDetailState({
    this.game,
    this.isLoading = false,
    this.error,
    this.myRole,
  });

  GameDetailState copyWith({
    SpandauerGame? game,
    bool? isLoading,
    String? error,
    Role? myRole,
  }) {
    return GameDetailState(
      game: game ?? this.game,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      myRole: myRole ?? this.myRole,
    );
  }
}

/// Notifier for a single game
class GameDetailNotifier extends StateNotifier<GameDetailState> {
  final WebViewApiClient _client;
  final int _currentUserId;
  final String _gameId;
  final int _threadId;
  final Ref _ref;

  GameDetailNotifier(
    this._client,
    this._currentUserId,
    this._gameId,
    this._threadId,
    this._ref,
  ) : super(const GameDetailState());

  /// Load game state from thread
  Future<void> loadGame() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    // In demo mode, return hardcoded demo game
    if (DemoConfig.demoMode) {
      final demoGame = getDemoGameById(_gameId);
      if (demoGame != null) {
        final myRole = getDemoUserRole(_gameId);
        state = state.copyWith(
          game: demoGame.withPerspective(_currentUserId),
          myRole: myRole,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Demo spil ikke fundet',
        );
      }
      return;
    }

    try {
      // Load messages for the thread
      final data = await _client.get(
        ApiEndpoints.getMessagesForThread,
        queryParams: {
          'threadId': _threadId,
          'page': 0,
        },
      );

      final messages = <Message>[];
      if (data is Map && data['messages'] is List) {
        for (final item in data['messages']) {
          messages.add(Message.fromJson(item));
        }
      } else if (data is List) {
        for (final item in data) {
          messages.add(Message.fromJson(item));
        }
      }

      // Get thread info
      final threadsState = _ref.read(threadsProvider);
      final thread = threadsState.threads.firstWhere(
        (t) => t.id == _threadId,
        orElse: () => Thread(id: _threadId, subject: 'Unknown'),
      );

      // Build game state
      final game = SpandauerEngine.fromThread(thread, messages, _currentUserId);

      if (game == null || game.id != _gameId) {
        state = state.copyWith(
          isLoading: false,
          error: 'Spil ikke fundet',
        );
        return;
      }

      // Decrypt own role
      Role? myRole;
      final rolesEvent = game.events.firstWhere(
        (e) => e.type == GameEventType.rolesAssigned,
        orElse: () => GameEvent(
          id: '',
          gameId: '',
          type: GameEventType.gameCreated,
          data: {},
          timestamp: DateTime.now(),
        ),
      );

      if (rolesEvent.type == GameEventType.rolesAssigned) {
        final encryptedRoles = rolesEvent.encryptedRoles;
        final myEncryptedRole = encryptedRoles?[_currentUserId.toString()];
        if (myEncryptedRole != null) {
          // Find game salt from game created event
          final gameSalt = game.id; // Using game ID as salt for simplicity
          myRole = RoleEncryption.decryptRole(
            myEncryptedRole,
            _currentUserId,
            gameSalt,
          );
        }
      }

      state = state.copyWith(
        game: game,
        myRole: myRole,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Submit an action (vote, kill, investigate, etc.)
  Future<bool> submitAction(GameEvent action) async {
    final game = state.game;
    if (game == null) return false;

    // In demo mode, actions are not persisted
    if (DemoConfig.demoMode) {
      state = state.copyWith(error: 'Handlinger er deaktiveret i demo-tilstand');
      return false;
    }

    // Validate action
    if (!SpandauerEngine.isValidAction(game, _currentUserId, action)) {
      state = state.copyWith(error: 'Ugyldig handling');
      return false;
    }

    try {
      // Encode and send as message
      final message = SpandauerProtocol.encode(action);
      await _client.post(
        ApiEndpoints.reply,
        body: {
          'threadId': _threadId,
          'message': {'text': message},
          'attachmentIds': [],
        },
      );

      // Reload game state
      await loadGame();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Vote for a player (day phase)
  Future<bool> vote(int targetId) async {
    final game = state.game;
    if (game == null) return false;

    final event = GameEvent.vote(
      gameId: game.id,
      voterId: _currentUserId,
      targetId: targetId,
    );

    return submitAction(event);
  }

  /// Kill a player (spandauer night action)
  Future<bool> spandauerKill(int targetId) async {
    final game = state.game;
    if (game == null) return false;

    final event = GameEvent.spandauerKill(
      gameId: game.id,
      actorId: _currentUserId,
      targetId: targetId,
    );

    return submitAction(event);
  }

  /// Investigate a player (seer night action)
  Future<bool> seerInvestigate(int targetId) async {
    final game = state.game;
    if (game == null) return false;

    final event = GameEvent.seerInvestigate(
      gameId: game.id,
      actorId: _currentUserId,
      targetId: targetId,
    );

    return submitAction(event);
  }

  /// Protect a player (healer night action)
  Future<bool> healerProtect(int targetId) async {
    final game = state.game;
    if (game == null) return false;

    final event = GameEvent.healerProtect(
      gameId: game.id,
      actorId: _currentUserId,
      targetId: targetId,
    );

    return submitAction(event);
  }

  /// Refresh game state
  Future<void> refresh() => loadGame();
}

/// Game detail provider family
final gameDetailProvider = StateNotifierProvider.family<GameDetailNotifier,
    GameDetailState, ({String gameId, int threadId})>((ref, params) {
  final client = ref.watch(webViewApiClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final currentUserId = profile?.id ?? 0;
  return GameDetailNotifier(
    client,
    currentUserId,
    params.gameId,
    params.threadId,
    ref,
  );
});

/// Create game state
class CreateGameState {
  final bool isCreating;
  final String? error;
  final SpandauerGame? createdGame;

  const CreateGameState({
    this.isCreating = false,
    this.error,
    this.createdGame,
  });

  CreateGameState copyWith({
    bool? isCreating,
    String? error,
    SpandauerGame? createdGame,
  }) {
    return CreateGameState(
      isCreating: isCreating ?? this.isCreating,
      error: error,
      createdGame: createdGame ?? this.createdGame,
    );
  }
}

/// Notifier for creating a new game
class CreateGameNotifier extends StateNotifier<CreateGameState> {
  final WebViewApiClient _client;
  final int _currentUserId;
  final Ref _ref;

  CreateGameNotifier(this._client, this._currentUserId, this._ref)
      : super(const CreateGameState());

  /// Create a new game in an existing thread
  Future<bool> createGame({
    required int threadId,
    required String name,
    required List<int> playerIds,
    GameConfig? config,
  }) async {
    if (state.isCreating) return false;
    state = state.copyWith(isCreating: true, error: null);

    try {
      final gameId = SpandauerProtocol.generateGameId();
      final gameConfig = config ?? GameConfig.recommended(playerIds.length);

      // Validate player count
      if (playerIds.length < gameConfig.minPlayers) {
        state = state.copyWith(
          isCreating: false,
          error: 'Mindst ${gameConfig.minPlayers} spillere kræves',
        );
        return false;
      }

      // Create game created event
      final gameCreatedEvent = GameEvent.gameCreated(
        gameId: gameId,
        hostId: _currentUserId,
        gameName: name,
        playerIds: playerIds,
      );

      // Assign and encrypt roles
      final roleAssignments = RoleEncryption.assignRoles(playerIds, gameConfig);
      final encryptedRoles =
          RoleEncryption.encryptRoles(roleAssignments, gameId);

      final rolesAssignedEvent = GameEvent.rolesAssigned(
        gameId: gameId,
        hostId: _currentUserId,
        encryptedRoles: encryptedRoles,
      );

      // Start first night
      final nightStartedEvent = GameEvent.nightStarted(
        gameId: gameId,
        nightNumber: 1,
      );

      // Send all events as messages
      for (final event
          in [gameCreatedEvent, rolesAssignedEvent, nightStartedEvent]) {
        final message = SpandauerProtocol.encode(event);
        await _client.post(
          ApiEndpoints.reply,
          body: {
            'threadId': threadId,
            'message': {'text': message},
            'attachmentIds': [],
          },
        );
      }

      // Refresh games list
      await _ref.read(gamesProvider.notifier).refresh();

      state = state.copyWith(isCreating: false);
      return true;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  /// Create a new thread and game
  Future<bool> createGameWithNewThread({
    required String threadSubject,
    required String gameName,
    required List<int> recipientIds,
    GameConfig? config,
  }) async {
    if (state.isCreating) return false;
    state = state.copyWith(isCreating: true, error: null);

    try {
      // Create the thread first
      final threadData = await _client.post(
        ApiEndpoints.startNewThread,
        body: {
          'recipientInstitutionProfileIds': recipientIds,
          'subject': threadSubject,
          'message': {'text': '<div>🎮 Spandauer spil starter!</div>'},
          'attachmentIds': [],
        },
      );

      // Extract thread ID from response
      int? threadId;
      if (threadData is Map) {
        threadId = threadData['threadId'] as int? ?? threadData['id'] as int?;
      }

      if (threadId == null) {
        state = state.copyWith(
          isCreating: false,
          error: 'Kunne ikke oprette beskedtråd',
        );
        return false;
      }

      // Include current user in players
      final allPlayerIds = {...recipientIds, _currentUserId}.toList();

      // Now create the game in this thread
      state = state.copyWith(isCreating: false);
      return createGame(
        threadId: threadId,
        name: gameName,
        playerIds: allPlayerIds,
        config: config,
      );
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Create game provider
final createGameProvider =
    StateNotifierProvider<CreateGameNotifier, CreateGameState>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final currentUserId = profile?.id ?? 0;
  return CreateGameNotifier(client, currentUserId, ref);
});
