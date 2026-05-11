import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../core/models/post.dart';
import '../../shared/widgets/app_spinner.dart';
import '../../shared/widgets/avatar.dart';
import 'wall_provider.dart';

class WallScreen extends ConsumerStatefulWidget {
  const WallScreen({super.key});

  @override
  ConsumerState<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends ConsumerState<WallScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Fetch posts on init
    Future.microtask(() {
      ref.read(wallProvider.notifier).fetchPosts();
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
      ref.read(wallProvider.notifier).fetchPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallState = ref.watch(wallProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(wallProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              title: const Text('Væg'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              floating: true,
              snap: true,
            ),
            if (wallState.posts.isEmpty && wallState.isLoading)
              const SliverFillRemaining(
                child: Center(child: AppSpinner()),
              )
            else if (wallState.posts.isEmpty && wallState.error != null)
              SliverFillRemaining(
                child: _buildError(wallState.error!),
              )
            else if (wallState.posts.isEmpty)
              SliverFillRemaining(
                child: _buildEmpty(),
              )
            else
              _buildPostsList(wallState),
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
              onPressed: () => ref.read(wallProvider.notifier).refresh(),
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
          HugeIcon(icon: HugeIcons.strokeRoundedDashboardSquare01, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Ingen opslag endnu'),
        ],
      ),
    );
  }

  Widget _buildPostsList(WallState wallState) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      sliver: SliverList.builder(
        itemCount: wallState.posts.length + (wallState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= wallState.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: AppSpinner()),
            );
          }
          return _PostCard(post: wallState.posts[index]);
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

  static final _dateFormat = DateFormat('d. MMM yyyy', 'da_DK');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author and date
            Row(
              children: [
                AvatarWidget(
                  name: post.author.name,
                  imageUrl: post.author.profilePicture,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _dateFormat.format(post.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.isPinned)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedPin,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),

            // Institution name
            if (post.institutionName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  post.institutionName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],

            // Title
            if (post.title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                post.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // Body
            if (post.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.body,
                style: theme.textTheme.bodyMedium,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Attachments indicator
            if (post.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in post.attachments)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: attachment.isImage ? HugeIcons.strokeRoundedImage01 : HugeIcons.strokeRoundedAttachment,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              attachment.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
