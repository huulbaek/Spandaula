import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../core/models/message.dart';
import '../../core/models/thread.dart';
import '../../shared/widgets/app_spinner.dart';
import '../../shared/widgets/avatar.dart';
import '../auth/auth_provider.dart';
import 'messages_provider.dart';

class ThreadDetailScreen extends ConsumerStatefulWidget {
  final int threadId;
  final Thread? initialThread;

  const ThreadDetailScreen({
    super.key,
    required this.threadId,
    this.initialThread,
  });

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(threadDetailProvider(widget.threadId).notifier).fetchMessages();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final success = await ref
        .read(threadDetailProvider(widget.threadId).notifier)
        .sendReply(text);

    setState(() => _isSending = false);

    if (success) {
      _messageController.clear();
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunne ikke sende besked')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(threadDetailProvider(widget.threadId));
    final theme = Theme.of(context);

    // Scroll to bottom when messages change
    if (detailState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detailState.thread?.subject ?? widget.initialThread?.subject ?? 'Besked',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: detailState.messages.isEmpty && detailState.isLoading
                ? _buildLoadingWithPreview()
                : detailState.messages.isEmpty && detailState.error != null
                ? _buildError(detailState.error!)
                : _buildMessagesList(detailState),
          ),

          // Reply input
          _buildReplyInput(theme),
        ],
      ),
    );
  }

  Widget _buildLoadingWithPreview() {
    // Show the latest message from initial thread as a preview while loading
    if (widget.initialThread?.latestMessage != null) {
      return Stack(
        children: [
          ListView(
            controller: _scrollController,
            children: [
              _buildDateHeader(widget.initialThread!.latestMessage!.timestamp),
              _MessageBubble(message: widget.initialThread!.latestMessage!),
            ],
          ),
          const Positioned.fill(
            child: Center(
              child: AppSpinner(),
            ),
          ),
        ],
      );
    }
    return const Center(child: AppSpinner());
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
              onPressed: () => ref
                  .read(threadDetailProvider(widget.threadId).notifier)
                  .refresh(),
              child: const Text('Prøv igen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(ThreadDetailState state) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(threadDetailProvider(widget.threadId).notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final message = state.messages[index];
          final showDateHeader =
              index == 0 ||
              !_isSameDay(
                state.messages[index - 1].timestamp,
                message.timestamp,
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDateHeader) _buildDateHeader(message.timestamp),
              _MessageBubble(message: message),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(DateTime date) {
    final dateFormat = DateFormat('EEEE d. MMMM yyyy', 'da_DK');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            dateFormat.format(date),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyInput(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Skriv en besked...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const AppSpinner(size: 20)
                : HugeIcon(icon: HugeIcons.strokeRoundedSent02),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm', 'da_DK');

    // Check if message is from current user
    final institutionProfileIds = ref.watch(institutionProfileIdsProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final isOwnMessage = institutionProfileIds.contains(message.sender.id) ||
        currentProfile?.id == message.sender.id;

    // Use primary color variant for own messages, surface for others
    final bubbleColor = isOwnMessage
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget(
            name: message.sender.name,
            imageUrl: message.sender.profilePicture,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name and time
                Row(
                  children: [
                    Text(
                      message.sender.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeFormat.format(message.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Message content
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(message.text, style: theme.textTheme.bodyMedium),
                ),
                // Attachments
                if (message.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: message.attachments.map((attachment) {
                      return ActionChip(
                        avatar: HugeIcon(
                          icon: attachment.isImage ? HugeIcons.strokeRoundedImage01 : HugeIcons.strokeRoundedAttachment,
                          size: 18,
                        ),
                        label: Text(
                          attachment.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          // TODO: Open attachment
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
