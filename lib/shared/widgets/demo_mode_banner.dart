import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/demo/demo_config.dart';
import '../../core/demo/demo_data_service.dart';

/// A subtle banner that shows when demo mode is active
class DemoModeBanner extends StatelessWidget {
  final Widget child;

  const DemoModeBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!DemoConfig.demoMode) {
      return child;
    }

    return Banner(
      message: 'DEMO',
      location: BannerLocation.topEnd,
      color: Colors.orange,
      child: child,
    );
  }
}

/// A small chip indicator for demo mode (alternative to banner)
class DemoModeChip extends StatelessWidget {
  const DemoModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DemoConfig.showBadge) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isRecording = DemoConfig.recordApi;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isRecording ? Colors.red.shade100 : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecording ? Colors.red.shade300 : Colors.orange.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRecording ? Icons.fiber_manual_record : Icons.play_circle_outline,
                size: 12,
                color: isRecording ? Colors.red : Colors.orange.shade800,
              ),
              const SizedBox(width: 4),
              Text(
                isRecording ? 'REC' : 'DEMO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isRecording ? Colors.red.shade800 : Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (isRecording) ...[
          const SizedBox(width: 8),
          _ExportButton(),
        ],
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _exportData(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 12, color: Colors.green.shade800),
              const SizedBox(width: 4),
              Text(
                'EXPORT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportData(BuildContext context) {
    final service = DemoDataService.instance;
    final count = service.recordingCount;

    // Copy to clipboard
    final json = service.exportRecordings();
    Clipboard.setData(ClipboardData(text: json));

    // Also print to console
    service.printRecordingsToConsole();

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Eksporteret $count API-kald til udklipsholder og konsol'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// A floating indicator that can be placed anywhere in the app
class DemoModeIndicator extends StatelessWidget {
  const DemoModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DemoConfig.showBadge) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 8,
      child: const DemoModeChip(),
    );
  }
}
