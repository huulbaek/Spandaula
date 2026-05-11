import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/webview_api_client.dart';
import '../../core/cache/cache_service.dart';
import '../../core/models/models.dart';
import '../auth/auth_provider.dart';

/// Threads list state
class ThreadsState {
  final List<Thread> threads;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;

  const ThreadsState({
    this.threads = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  ThreadsState copyWith({
    List<Thread>? threads,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) {
    return ThreadsState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Threads notifier
class ThreadsNotifier extends StateNotifier<ThreadsState> {
  final WebViewApiClient _client;
  final CacheService _cacheService;

  ThreadsNotifier(this._client, this._cacheService) : super(const ThreadsState()) {
    _loadCachedThreads();
  }

  void _loadCachedThreads() {
    final cached = _cacheService.getCachedThreads();
    if (cached.isNotEmpty) {
      state = state.copyWith(threads: cached);
    }
  }

  Future<void> fetchThreads({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 0 : state.currentPage;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _client.get(
        ApiEndpoints.getThreads,
        queryParams: {
          'sortOn': 'date',
          'orderDirection': 'desc',
          'page': page,
        },
      );

      final newThreads = <Thread>[];
      // Handle both List and Map with 'threads' key
      List? threadsList;
      if (data is List) {
        threadsList = data;
      } else if (data is Map && data['threads'] is List) {
        threadsList = data['threads'] as List;
      }

      if (threadsList != null) {
        for (final item in threadsList) {
          newThreads.add(Thread.fromJson(item));
        }
      }

      // Cache the threads
      await _cacheService.cacheThreads(newThreads);

      final allThreads = refresh ? newThreads : [...state.threads, ...newThreads];

      state = state.copyWith(
        threads: allThreads,
        isLoading: false,
        hasMore: newThreads.isNotEmpty,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => fetchThreads(refresh: true);

  void markThreadAsRead(int threadId) {
    final threads = state.threads.map((t) {
      if (t.id == threadId) {
        return t.copyWith(hasUnread: false);
      }
      return t;
    }).toList();
    state = state.copyWith(threads: threads);
    _cacheService.cacheThreads(threads);
  }
}

/// Threads provider
final threadsProvider = StateNotifierProvider<ThreadsNotifier, ThreadsState>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return ThreadsNotifier(client, cacheService);
});

/// Thread detail state
class ThreadDetailState {
  final Thread? thread;
  final List<Message> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;

  const ThreadDetailState({
    this.thread,
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  ThreadDetailState copyWith({
    Thread? thread,
    List<Message>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) {
    return ThreadDetailState(
      thread: thread ?? this.thread,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Thread detail notifier
class ThreadDetailNotifier extends StateNotifier<ThreadDetailState> {
  final WebViewApiClient _client;
  final CacheService _cacheService;
  final int threadId;
  final void Function(int)? onMarkAsRead;

  ThreadDetailNotifier(
    this._client,
    this._cacheService,
    this.threadId, {
    this.onMarkAsRead,
  }) : super(const ThreadDetailState()) {
    _loadCachedMessages();
  }

  void _loadCachedMessages() {
    final cached = _cacheService.getCachedMessagesForThread(threadId);
    final thread = _cacheService.getCachedThread(threadId);
    if (cached.isNotEmpty || thread != null) {
      state = state.copyWith(messages: cached, thread: thread);
    }
  }

  Future<void> fetchMessages({bool refresh = false, bool markAsRead = true}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 0 : state.currentPage;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _client.get(
        ApiEndpoints.getMessagesForThread,
        queryParams: {
          'threadId': threadId,
          'page': page,
        },
      );

      final newMessages = <Message>[];
      Thread? thread;

      // debugPrint('ThreadDetail: Got data type: ${data.runtimeType}');
      // debugPrint('ThreadDetail: Data: $data');

      if (data is Map) {
        // Thread info might be in the response
        if (data['messages'] is List) {
          for (final item in data['messages']) {
            try {
              newMessages.add(Message.fromJson(item));
            } catch (e) {
              debugPrint('ThreadDetail: Error parsing message: $e');
              debugPrint('ThreadDetail: Message JSON: $item');
              rethrow;
            }
          }
        }
        if (data['thread'] != null) {
          try {
            thread = Thread.fromJson(data['thread']);
          } catch (e) {
            debugPrint('ThreadDetail: Error parsing thread: $e');
            debugPrint('ThreadDetail: Thread JSON: ${data['thread']}');
            rethrow;
          }
        }
      } else if (data is List) {
        for (final item in data) {
          try {
            newMessages.add(Message.fromJson(item));
          } catch (e) {
            debugPrint('ThreadDetail: Error parsing message: $e');
            debugPrint('ThreadDetail: Message JSON: $item');
            rethrow;
          }
        }
      }

      // Cache the messages
      await _cacheService.cacheMessages(threadId, newMessages);

      final allMessages = refresh ? newMessages : [...state.messages, ...newMessages];
      // Sort oldest first
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      state = state.copyWith(
        thread: thread ?? state.thread,
        messages: allMessages,
        isLoading: false,
        hasMore: newMessages.isNotEmpty,
        currentPage: page + 1,
      );

      // Mark thread as read
      if (markAsRead && (refresh || page == 0)) {
        _markAsRead();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _markAsRead() async {
    if (state.messages.isEmpty) return;

    // Get the last (most recent) message ID
    final lastMessage = state.messages.last;

    try {
      await _client.post(
        ApiEndpoints.setLastReadMessage,
        body: {
          'threadId': threadId,
          'messageId': lastMessage.id,
          'commonInboxId': null,
          'otpInboxId': null,
        },
      );
      onMarkAsRead?.call(threadId);
    } catch (_) {
      // Ignore errors for marking as read
    }
  }

  Future<void> refresh() => fetchMessages(refresh: true);

  Future<bool> sendReply(String text) async {
    try {
      final htmlText = '<div>$text</div>';
      await _client.post(
        ApiEndpoints.reply,
        body: {
          'threadId': threadId,
          'message': {'text': htmlText},
          'attachmentIds': [],
        },
      );
      // Refresh to get the new message
      await refresh();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Thread detail provider family
final threadDetailProvider = StateNotifierProvider.family<ThreadDetailNotifier, ThreadDetailState, int>((ref, threadId) {
  final client = ref.watch(webViewApiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  final threadsNotifier = ref.read(threadsProvider.notifier);
  return ThreadDetailNotifier(
    client,
    cacheService,
    threadId,
    onMarkAsRead: threadsNotifier.markThreadAsRead,
  );
});

/// Recipients search state
class RecipientsSearchState {
  final List<Recipient> results;
  final bool isLoading;
  final String? error;
  final String query;

  const RecipientsSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  RecipientsSearchState copyWith({
    List<Recipient>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return RecipientsSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

/// Recipients search notifier
class RecipientsSearchNotifier extends StateNotifier<RecipientsSearchState> {
  final WebViewApiClient _client;
  final List<int> _institutionProfileIds;
  final List<String> _institutionCodes;

  RecipientsSearchNotifier(this._client, this._institutionProfileIds, this._institutionCodes)
      : super(const RecipientsSearchState());

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const RecipientsSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null, query: query);

    // Use first institution profile ID as mailbox owner
    final mailBoxOwnerId = _institutionProfileIds.isNotEmpty ? _institutionProfileIds.first : null;
    // Use first institution code
    final instCode = _institutionCodes.isNotEmpty ? _institutionCodes.first : null;

    try {
      final data = await _client.get(
        ApiEndpoints.findRecipients,
        queryParams: {
          'text': query,
          'query': query,
          'typeahead': true,
          'limit': 100,
          'scopeEmployeesToInstitution': false,
          'fromModule': 'messages',
          if (mailBoxOwnerId != null) 'mailBoxOwnerId': mailBoxOwnerId,
          'mailBoxOwnerType': 'institutionProfile',
          'portalRoles': ['child', 'guardian', 'employee', 'otp'],
          if (instCode != null) 'instCode': instCode,
          'docTypes': ['Group', 'Profile', 'CommonInbox'],
        },
      );

      final results = <Recipient>[];

      // Handle both List and Map with 'results' or 'recipients' key
      List? recipientsList;
      if (data is List) {
        recipientsList = data;
      } else if (data is Map) {
        // Try different possible keys
        recipientsList = data['results'] as List? ??
                         data['recipients'] as List? ??
                         data['data'] as List?;
      }

      if (recipientsList != null) {
        for (final item in recipientsList) {
          try {
            results.add(Recipient.fromJson(item));
          } catch (e) {
            // Skip recipients that fail to parse
            debugPrint('findRecipients: Error parsing recipient: $e');
          }
        }
      }

      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clear() {
    state = const RecipientsSearchState();
  }
}

/// Recipients search provider
final recipientsSearchProvider =
    StateNotifierProvider<RecipientsSearchNotifier, RecipientsSearchState>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  final institutionIds = ref.watch(institutionProfileIdsProvider);
  final institutionCodes = ref.watch(institutionCodesProvider);
  return RecipientsSearchNotifier(client, institutionIds, institutionCodes);
});

/// Message search state
class MessageSearchState {
  final List<Thread> results;
  final bool isLoading;
  final String? error;
  final String query;

  const MessageSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  MessageSearchState copyWith({
    List<Thread>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return MessageSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

/// Message search notifier
class MessageSearchNotifier extends StateNotifier<MessageSearchState> {
  final WebViewApiClient _client;

  MessageSearchNotifier(this._client) : super(const MessageSearchState());

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const MessageSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null, query: query);

    try {
      final data = await _client.post(
        ApiEndpoints.findMessage,
        body: {
          'text': query,
          'limit': 30,
          'offset': 0,
        },
      );

      final results = <Thread>[];
      // Handle both List and Map with 'threads' key
      List? threadsList;
      if (data is List) {
        threadsList = data;
      } else if (data is Map && data['threads'] is List) {
        threadsList = data['threads'] as List;
      }

      if (threadsList != null) {
        for (final item in threadsList) {
          results.add(Thread.fromJson(item));
        }
      }

      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clear() {
    state = const MessageSearchState();
  }
}

/// Message search provider
final messageSearchProvider =
    StateNotifierProvider<MessageSearchNotifier, MessageSearchState>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  return MessageSearchNotifier(client);
});

/// Compose message notifier
class ComposeMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final WebViewApiClient _client;

  ComposeMessageNotifier(this._client) : super(const AsyncValue.data(null));

  Future<bool> sendNewMessage({
    required List<int> recipientIds,
    required String subject,
    required String message,
  }) async {
    state = const AsyncValue.loading();

    try {
      final htmlMessage = '<div>$message</div>';
      await _client.post(
        ApiEndpoints.startNewThread,
        body: {
          'recipientInstitutionProfileIds': recipientIds,
          'subject': subject,
          'message': {'text': htmlMessage},
          'attachmentIds': [],
        },
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Compose message provider
final composeMessageProvider =
    StateNotifierProvider<ComposeMessageNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  return ComposeMessageNotifier(client);
});
