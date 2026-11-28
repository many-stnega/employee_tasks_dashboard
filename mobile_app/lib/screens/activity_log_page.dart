import 'package:material_ui/material_ui.dart';

import '../activity_log.dart';
import '../format.dart';

class ActivityLogPage extends StatelessWidget {
  const ActivityLogPage({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear activity log?'),
        content: const Text(
          'All locally stored entries will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await activityLog.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: activityLog,
      builder: (context, _) {
        final entries = activityLog.entries;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Activity Log'),
            actions: [
              IconButton(
                tooltip: 'Clear log',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: entries.isEmpty ? null : () => _confirmClear(context),
              ),
            ],
          ),
          body: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 48, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('No activity yet',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Syncs, cron jobs, SMS and settings changes appear here. Stored on this device only.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_iconFor(entry.source),
                                size: 20, color: scheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.message,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${entry.source.toUpperCase()} · ${dateTimeLabel(entry.at)} · MMT',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  IconData _iconFor(String source) => switch (source) {
        'sync' || 'background' => Icons.sync,
        'cron' => Icons.schedule,
        'sms' => Icons.sms_outlined,
        'admin' => Icons.admin_panel_settings_outlined,
        _ => Icons.event_note_outlined,
      };
}
