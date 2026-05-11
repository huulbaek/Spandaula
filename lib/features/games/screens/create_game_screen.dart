import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models/recipient.dart';
import '../../../shared/widgets/app_spinner.dart';
import '../../messages/messages_provider.dart';
import '../protocol/protocol.dart';
import '../providers/games_provider.dart';

class CreateGameScreen extends ConsumerStatefulWidget {
  const CreateGameScreen({super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  final _nameController = TextEditingController(text: 'Spandauer');
  final _searchController = TextEditingController();
  final _selectedRecipients = <Recipient>[];

  int _spandauerCount = 1;
  bool _includeSeer = true;
  bool _includeHealer = false;
  bool _includeHunter = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createState = ref.watch(createGameProvider);
    final searchState = ref.watch(recipientsSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nyt spil'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Game name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Spilnavn',
                    hintText: 'Spandauer',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Player search
                Text(
                  'Tilføj spillere',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Søg efter spillere...',
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
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(recipientsSearchProvider.notifier).clear();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    if (value.length >= 2) {
                      ref.read(recipientsSearchProvider.notifier).search(value);
                    }
                  },
                ),

                // Search results
                if (searchState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: AppSpinner()),
                  )
                else if (searchState.results.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: searchState.results
                          .where((r) => !_selectedRecipients
                              .any((s) => s.id == r.id))
                          .take(5)
                          .map((recipient) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    recipient.name.isNotEmpty
                                        ? recipient.name[0]
                                        : '?',
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                title: Text(recipient.name),
                                subtitle: recipient.institutionName != null
                                    ? Text(recipient.institutionName!)
                                    : null,
                                trailing: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
                                onTap: () {
                                  setState(() {
                                    _selectedRecipients.add(recipient);
                                  });
                                  _searchController.clear();
                                  ref
                                      .read(recipientsSearchProvider.notifier)
                                      .clear();
                                  _updateRecommendedConfig();
                                },
                              ))
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 16),

                // Selected players
                if (_selectedRecipients.isNotEmpty) ...[
                  Text(
                    'Valgte spillere (${_selectedRecipients.length})',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedRecipients
                        .map((r) => Chip(
                              avatar: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  r.name.isNotEmpty ? r.name[0] : '?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              label: Text(r.name),
                              onDeleted: () {
                                setState(() {
                                  _selectedRecipients.remove(r);
                                });
                                _updateRecommendedConfig();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Game config
                Text(
                  'Spilindstillinger',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Spandauer count
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Antal spandauere',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _spandauerCount > 1
                          ? () => setState(() => _spandauerCount--)
                          : null,
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedMinusSign),
                    ),
                    Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: Text(
                        '$_spandauerCount',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _spandauerCount++),
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
                    ),
                  ],
                ),

                // Special roles
                SwitchListTile(
                  title: const Text('Seer'),
                  subtitle: const Text('Kan undersøge spillere om natten'),
                  secondary: const Text('👁️', style: TextStyle(fontSize: 24)),
                  value: _includeSeer,
                  onChanged: (v) => setState(() => _includeSeer = v),
                ),
                SwitchListTile(
                  title: const Text('Heler'),
                  subtitle: const Text('Kan beskytte spillere om natten'),
                  secondary: const Text('💚', style: TextStyle(fontSize: 24)),
                  value: _includeHealer,
                  onChanged: (v) => setState(() => _includeHealer = v),
                ),
                SwitchListTile(
                  title: const Text('Jæger'),
                  subtitle: const Text('Kan dræbe én spiller når de dør'),
                  secondary: const Text('🏹', style: TextStyle(fontSize: 24)),
                  value: _includeHunter,
                  onChanged: (v) => setState(() => _includeHunter = v),
                ),

                const SizedBox(height: 16),

                // Player count info
                _buildPlayerCountInfo(theme),

                if (createState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedAlertCircle,
                                color: theme.colorScheme.error),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                createState.error!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Create button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _canCreate() && !createState.isCreating
                    ? _createGame
                    : null,
                icon: createState.isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : HugeIcon(icon: HugeIcons.strokeRoundedPlay),
                label: Text(
                    createState.isCreating ? 'Opretter...' : 'Start spil'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCountInfo(ThemeData theme) {
    final totalPlayers = _selectedRecipients.length + 1; // +1 for self
    final minPlayers = _calculateMinPlayers();
    final isValid = totalPlayers >= minPlayers;

    return Card(
      color: isValid
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(
                  icon: isValid ? HugeIcons.strokeRoundedCheckmarkCircle01 : HugeIcons.strokeRoundedAlert01,
                  color: isValid
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  isValid
                      ? '$totalPlayers spillere (inkl. dig)'
                      : 'Mindst $minPlayers spillere kræves',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isValid
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getRoleDistributionText(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateMinPlayers() {
    // spandauers + special roles + at least 1 villager
    return _spandauerCount +
        (_includeSeer ? 1 : 0) +
        (_includeHealer ? 1 : 0) +
        (_includeHunter ? 1 : 0) +
        1;
  }

  String _getRoleDistributionText() {
    final parts = <String>[];
    parts.add('$_spandauerCount spandauer${_spandauerCount > 1 ? 'e' : ''}');
    if (_includeSeer) parts.add('1 seer');
    if (_includeHealer) parts.add('1 heler');
    if (_includeHunter) parts.add('1 jæger');
    final remaining = (_selectedRecipients.length + 1) - _calculateMinPlayers() + 1;
    if (remaining > 0) {
      parts.add('$remaining landsbyboer${remaining > 1 ? 'e' : ''}');
    }
    return 'Roller: ${parts.join(', ')}';
  }

  bool _canCreate() {
    final totalPlayers = _selectedRecipients.length + 1;
    return _nameController.text.isNotEmpty &&
        _selectedRecipients.isNotEmpty &&
        totalPlayers >= _calculateMinPlayers();
  }

  void _updateRecommendedConfig() {
    final playerCount = _selectedRecipients.length + 1;
    final recommended = GameConfig.recommended(playerCount);
    setState(() {
      _spandauerCount = recommended.spandauerCount;
      _includeSeer = recommended.includeSeer;
      _includeHealer = recommended.includeHealer;
      _includeHunter = recommended.includeHunter;
    });
  }

  Future<void> _createGame() async {
    final config = GameConfig(
      spandauerCount: _spandauerCount,
      includeSeer: _includeSeer,
      includeHealer: _includeHealer,
      includeHunter: _includeHunter,
    );

    final recipientIds = _selectedRecipients.map((r) => r.id).toList();

    final success = await ref
        .read(createGameProvider.notifier)
        .createGameWithNewThread(
          threadSubject: '🥐 ${_nameController.text}',
          gameName: _nameController.text,
          recipientIds: recipientIds,
          config: config,
        );

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }
}
