import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Service for managing local cache with Hive
class CacheService {
  // Box name constants kept for when caching is re-enabled.
  // ignore: unused_field
  static const String _threadsBoxName = 'threads';
  // ignore: unused_field
  static const String _messagesBoxName = 'messages';
  // ignore: unused_field
  static const String _postsBoxName = 'posts';

  /// Initialize Hive
  /// TODO: Add type adapters when hive_generator is compatible with riverpod_generator
  static Future<void> initHive() async {
    await Hive.initFlutter();
    // Type adapters disabled for now - caching will be no-op
  }

  Future<void> init() async {
    // Disabled until Hive adapters are generated
  }

  // Threads - no-op until caching is re-enabled
  Future<void> cacheThreads(List<Thread> threads) async {}
  List<Thread> getCachedThreads() => [];
  Thread? getCachedThread(int threadId) => null;
  Future<void> updateThread(Thread thread) async {}

  // Messages - no-op until caching is re-enabled
  Future<void> cacheMessages(int threadId, List<Message> messages) async {}
  List<Message> getCachedMessages(int threadId) => [];
  List<Message> getCachedMessagesForThread(int threadId) => [];

  // Posts - no-op until caching is re-enabled
  Future<void> cachePosts(List<Post> posts) async {}
  List<Post> getCachedPosts() => [];

  // Clear cache - no-op
  Future<void> clearThreads() async {}
  Future<void> clearMessages() async {}
  Future<void> clearPosts() async {}
  Future<void> clearAll() async {}
  Future<void> close() async {}
}
