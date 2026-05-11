import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../shared/utils/page_transitions.dart';
import '../../shared/widgets/app_spinner.dart';
import '../../shared/widgets/avatar.dart';
import 'messages_provider.dart';
import 'thread_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.length >= 2) {
      ref.read(messageSearchProvider.notifier).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(messageSearchProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Søg i beskeder...',
            border: InputBorder.none,
          ),
          onSubmitted: _onSearch,
          textInputAction: TextInputAction.search,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
              onPressed: () {
                _searchController.clear();
                ref.read(messageSearchProvider.notifier).clear();
              },
            ),
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01),
            onPressed: () => _onSearch(_searchController.text),
          ),
        ],
      ),
      body: searchState.isLoading
          ? const Center(child: AppSpinner())
          : searchState.error != null
              ? _buildError(searchState.error!)
              : searchState.results.isEmpty
                  ? _buildEmpty(searchState.query)
                  : _buildResults(searchState),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String query) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Søg efter beskeder'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedSearchRemove, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Ingen resultater for "$query"'),
        ],
      ),
    );
  }

  Widget _buildResults(MessageSearchState state) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d. MMM yyyy', 'da_DK');

    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final thread = state.results[index];
        final participantNames = thread.participants
            .take(3)
            .map((p) => p.name.split(' ').first)
            .join(', ');

        return ListTile(
          leading: thread.participants.isNotEmpty
              ? AvatarWidget(
                  name: thread.participants.first.name,
                  imageUrl: thread.participants.first.profilePicture,
                  size: 48,
                )
              : CircleAvatar(child: HugeIcon(icon: HugeIcons.strokeRoundedUserCircle)),
          title: Text(
            thread.subject.isNotEmpty ? thread.subject : '(Intet emne)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (participantNames.isNotEmpty)
                Text(
                  participantNames,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              if (thread.lastMessageDate != null)
                Text(
                  dateFormat.format(thread.lastMessageDate!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
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
      },
    );
  }
}
