import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../core/models/thread.dart';
import '../../shared/utils/page_transitions.dart';
import '../../shared/widgets/app_spinner.dart';
import '../../shared/widgets/avatar.dart';
import 'messages_provider.dart';
import 'thread_detail_screen.dart';
import 'compose_screen.dart';
import 'search_screen.dart';

class ThreadsScreen extends ConsumerStatefulWidget {
  const ThreadsScreen({super.key});

  @override
  ConsumerState<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends ConsumerState<ThreadsScreen> {
  final _scrollController = ScrollController();
  final Set<int> _preloadedThreadIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(threadsProvider.notifier).fetchThreads();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(threadsProvider.notifier).fetchThreads();
    }
  }

  void _preloadFirstFiveThreads(List<Thread> threads) {
    // Preload the first 5 threads that haven't been preloaded yet
    final threadsToPreload = threads
        .take(5)
        .where((t) => !_preloadedThreadIds.contains(t.id))
        .toList();

    for (final thread in threadsToPreload) {
      _preloadedThreadIds.add(thread.id);
      // Trigger the provider to start fetching (this will cache the result)
      // Don't mark as read during preload - only when user actually opens the thread
      ref.read(threadDetailProvider(thread.id).notifier).fetchMessages(markAsRead: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadsState = ref.watch(threadsProvider);

    // Preload first 5 threads when threads are available
    if (threadsState.threads.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadFirstFiveThreads(threadsState.threads);
      });
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'compose_message_fab',
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ComposeScreen()));
        },
        shape: const CircleBorder(),
        child: HugeIcon(icon: HugeIcons.strokeRoundedEdit02),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(threadsProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              title: const Text('Beskeder'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              floating: true,
              snap: true,
              actions: [
                IconButton(
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01),
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
                  },
                ),
              ],
            ),
            if (threadsState.threads.isEmpty && threadsState.isLoading)
              const SliverFillRemaining(
                child: Center(child: AppSpinner()),
              )
            else if (threadsState.threads.isEmpty && threadsState.error != null)
              SliverFillRemaining(
                child: _buildError(threadsState.error!),
              )
            else if (threadsState.threads.isEmpty)
              SliverFillRemaining(
                child: _buildEmpty(),
              )
            else
              _buildThreadsList(threadsState),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedAlertCircle, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(threadsProvider.notifier).refresh(),
              child: const Text('Prøv igen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedMail01, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Ingen beskeder endnu'),
        ],
      ),
    );
  }

  Widget _buildThreadsList(ThreadsState threadsState) {
    return SliverList.builder(
      itemCount: threadsState.threads.length + (threadsState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= threadsState.threads.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: AppSpinner()),
          );
        }
        return _ThreadTile(thread: threadsState.threads[index]);
      },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final Thread thread;

  const _ThreadTile({required this.thread});

  static final _dateFormat = DateFormat('d. MMM', 'da_DK');
  static final _timeFormat = DateFormat('HH:mm', 'da_DK');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine display date - try lastMessageDate first, then latestMessage.timestamp
    String dateStr = '';
    final date = thread.lastMessageDate ?? thread.latestMessage?.timestamp;
    if (date != null) {
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        dateStr = _timeFormat.format(date);
      } else {
        dateStr = _dateFormat.format(date);
      }
    }

    // Get participant names (excluding current user ideally)
    final participantNames = thread.participants
        .take(3)
        .map((p) => p.name.split(' ').first)
        .join(', ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: thread.participants.isNotEmpty
          ? AvatarWidget(
              name: thread.participants.first.name,
              imageUrl: thread.participants.first.profilePicture,
              size: 48,
            )
          : CircleAvatar(child: HugeIcon(icon: HugeIcons.strokeRoundedUserCircle)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              thread.subject.isNotEmpty ? thread.subject : '(Intet emne)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: thread.hasUnread
                  ? theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                  : theme.textTheme.titleMedium,
            ),
          ),
          if (dateStr.isNotEmpty)
            Text(
              dateStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: thread.hasUnread
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (participantNames.isNotEmpty)
            Text(
              participantNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (thread.latestMessage != null)
            Text(
              thread.latestMessage!.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: thread.hasUnread
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () {
        Navigator.of(context).push(
          pushTransition(
            type: PageTransitionType.fade,
            duration: const Duration(milliseconds: 100),
            child: ThreadDetailScreen(
              threadId: thread.id,
              initialThread: thread,
            ),
          ),
        );
      },
    );
  }
}
