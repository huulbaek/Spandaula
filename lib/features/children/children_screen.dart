import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/models/profile.dart';
import '../auth/auth_provider.dart';
import 'children_provider.dart';

class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final children = profile?.children ?? [];
    final theme = Theme.of(context);

    // Listen for state changes to show snackbars
    ref.listen<ReportSickState>(childrenProvider, (previous, next) {
      if (next.successMessage != null && previous?.successMessage != next.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Clear state after showing snackbar
        Future.microtask(() => ref.read(childrenProvider.notifier).clearState());
      } else if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Clear state after showing snackbar
        Future.microtask(() => ref.read(childrenProvider.notifier).clearState());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Børn'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: children.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedBaby01,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ingen børn fundet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return _ChildCard(
                  child: child,
                  parentName: profile?.fullName ?? '',
                );
              },
            ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  final ChildProfile child;
  final String parentName;

  const _ChildCard({
    required this.child,
    required this.parentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(childrenProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: child.profilePicture != null
                  ? NetworkImage(child.profilePicture!)
                  : null,
              child: child.profilePicture == null
                  ? Text(
                      _getInitials(child.fullName),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Name and institution
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (child.institutionName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      child.institutionName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Meld syg button
            FilledButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => _showReportSickDialog(context, ref),
              icon: state.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : HugeIcon(icon: HugeIcons.strokeRoundedThermometer, size: 18),
              label: const Text('Meld syg'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSickDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meld syg'),
        content: Text(
          'Vil du sende en besked til ${child.firstName}s første lærer i dag om at barnet er syg?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(childrenProvider.notifier).reportSick(
                    child: child,
                    parentName: parentName,
                  );
            },
            child: const Text('Send besked'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}
