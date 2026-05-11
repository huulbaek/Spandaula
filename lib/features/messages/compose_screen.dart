import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/models/recipient.dart';
import '../../shared/widgets/app_spinner.dart';
import '../../shared/widgets/avatar.dart';
import 'messages_provider.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final List<Recipient> _selectedRecipients = [];
  bool _showSearch = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(recipientsSearchProvider.notifier).search(query);
  }

  void _addRecipient(Recipient recipient) {
    if (!_selectedRecipients.any((r) => r.id == recipient.id)) {
      setState(() {
        _selectedRecipients.add(recipient);
        _showSearch = false;
        _searchController.clear();
      });
      ref.read(recipientsSearchProvider.notifier).clear();
    }
  }

  void _removeRecipient(Recipient recipient) {
    setState(() {
      _selectedRecipients.removeWhere((r) => r.id == recipient.id);
    });
  }

  Future<void> _sendMessage() async {
    if (_selectedRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vælg mindst én modtager')),
      );
      return;
    }

    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skriv et emne')),
      );
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skriv en besked')),
      );
      return;
    }

    final recipientIds = _selectedRecipients.map((r) => r.id).toList();

    final success = await ref.read(composeMessageProvider.notifier).sendNewMessage(
      recipientIds: recipientIds,
      subject: subject,
      message: message,
    );

    if (success && mounted) {
      // Refresh threads list
      ref.read(threadsProvider.notifier).refresh();
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunne ikke sende besked')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(recipientsSearchProvider);
    final composeState = ref.watch(composeMessageProvider);
    final isSending = composeState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ny besked'),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          TextButton(
            onPressed: isSending ? null : _sendMessage,
            child: isSending
                ? const AppSpinner(size: 20)
                : const Text('Send'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Recipients section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Til:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ..._selectedRecipients.map((recipient) {
                            return Chip(
                              avatar: AvatarWidget(
                                name: recipient.name,
                                imageUrl: recipient.profilePicture,
                                size: 24,
                              ),
                              label: Text(recipient.name),
                              onDeleted: () => _removeRecipient(recipient),
                              visualDensity: VisualDensity.compact,
                            );
                          }),
                          ActionChip(
                            avatar: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18),
                            label: const Text('Tilføj'),
                            padding: EdgeInsets.only(top: 4, bottom: 4),
                            onPressed: () {
                              setState(() => _showSearch = true);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_showSearch) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Søg efter modtager...',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          size: 20,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixIcon: IconButton(
                        icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
                        onPressed: () {
                          setState(() {
                            _showSearch = false;
                            _searchController.clear();
                          });
                          ref.read(recipientsSearchProvider.notifier).clear();
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  if (searchState.isLoading)
                    const LinearProgressIndicator()
                  else if (searchState.results.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchState.results.length,
                        itemBuilder: (context, index) {
                          final recipient = searchState.results[index];
                          final isSelected = _selectedRecipients.any(
                            (r) => r.id == recipient.id,
                          );
                          return ListTile(
                            leading: AvatarWidget(
                              name: recipient.name,
                              imageUrl: recipient.profilePicture,
                              size: 40,
                            ),
                            title: Text(recipient.name),
                            subtitle: recipient.institutionName != null
                                ? Text(recipient.institutionName!)
                                : null,
                            trailing: isSelected
                                ? HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: Colors.green)
                                : null,
                            onTap: () => _addRecipient(recipient),
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Subject
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              hintText: 'Emne',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),

          // Message body
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Skriv din besked...',
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ],
      ),
    );
  }
}
