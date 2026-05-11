import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/webview_api_client.dart';
import '../../core/cache/cache_service.dart';
import '../../core/models/post.dart';
import '../auth/auth_provider.dart';

/// Wall posts state
class WallState {
  final List<Post> posts;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentIndex;

  const WallState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentIndex = 0,
  });

  WallState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentIndex,
  }) {
    return WallState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

/// Wall notifier for managing posts
class WallNotifier extends StateNotifier<WallState> {
  final WebViewApiClient _client;
  final CacheService _cacheService;
  final List<int> _institutionProfileIds;

  static const int _pageSize = 20;

  WallNotifier(this._client, this._cacheService, this._institutionProfileIds)
      : super(const WallState()) {
    _loadCachedPosts();
  }

  void _loadCachedPosts() {
    final cached = _cacheService.getCachedPosts();
    if (cached.isNotEmpty) {
      state = state.copyWith(posts: cached);
    }
  }

  Future<void> fetchPosts({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final startIndex = refresh ? 0 : state.currentIndex;
    state = state.copyWith(isLoading: true, error: null);

    debugPrint('WallProvider: Fetching posts, institutionProfileIds: $_institutionProfileIds');
    debugPrint('WallProvider: Client has controller: ${_client.hasController}');

    try {
      final data = await _client.get(
        ApiEndpoints.getAllPosts,
        queryParams: {
          'institutionProfileIds': _institutionProfileIds,
          'limit': _pageSize,
          'index': startIndex,
        },
      );

      debugPrint('WallProvider: Got data type: ${data.runtimeType}');

      final newPosts = <Post>[];
      // Handle both List and Map with 'posts' key
      List? postsList;
      if (data is List) {
        postsList = data;
      } else if (data is Map && data['posts'] is List) {
        postsList = data['posts'] as List;
      }

      if (postsList != null) {
        for (final item in postsList) {
          try {
            newPosts.add(Post.fromJson(item));
          } catch (e, st) {
            debugPrint('WallProvider: Error parsing post: $e');
            debugPrint('WallProvider: Post JSON: $item');
            debugPrint('WallProvider: Stack trace: $st');
            rethrow;
          }
        }
      }
      debugPrint('WallProvider: Parsed ${newPosts.length} posts');

      // Cache the posts
      await _cacheService.cachePosts(newPosts);

      final allPosts = refresh ? newPosts : [...state.posts, ...newPosts];

      // Sort: pinned first, then by date
      allPosts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });

      state = state.copyWith(
        posts: allPosts,
        isLoading: false,
        hasMore: newPosts.length >= _pageSize,
        currentIndex: startIndex + newPosts.length,
      );
    } catch (e, st) {
      debugPrint('WallProvider: Error fetching posts: $e');
      debugPrint('WallProvider: Stack trace: $st');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => fetchPosts(refresh: true);
}

/// Wall provider
final wallProvider = StateNotifierProvider<WallNotifier, WallState>((ref) {
  final client = ref.watch(webViewApiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  final institutionIds = ref.watch(institutionProfileIdsProvider);
  return WallNotifier(client, cacheService, institutionIds);
});
