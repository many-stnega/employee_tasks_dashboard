import 'package:material_ui/material_ui.dart';

import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';

class TaskCard extends StatefulWidget {
  final TaskItem task;

  const TaskCard({super.key, required this.task});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _expanded = false;
  bool _engineerRevealed = false;

  void _revealEngineer(String? username) {
    final handle = (username ?? '').replaceFirst(RegExp(r'^@'), '');
    if (handle.isEmpty) return;
    setState(() => _engineerRevealed = true);
    launchUrl(Uri.parse('https://t.me/$handle'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context, 'Task - ${task.id.isEmpty ? '—' : task.id}'),
                      const SizedBox(height: 4),
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (task.isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _chip(context, '✅ Completed'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _label(context, 'Engineer'),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _revealEngineer(task.assigneeUsername),
                        onLongPress: () =>
                            _revealEngineer(task.assigneeUsername),
                        borderRadius: BorderRadius.circular(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              engineerDisplayName(task.assigneeUsername,
                                  fallbackName: task.assigneeName),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: scheme.secondary,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (_engineerRevealed &&
                                (task.assigneeUsername ?? '').isNotEmpty)
                              Text('@${task.assigneeUsername}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 11, color: scheme.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.createdAt == null
                        ? 'Created time unavailable'
                        : 'Created ${dateTimeLabel(task.createdAt)} · MMT',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Collapse details' : 'Expand details',
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final left = _assignmentColumn(context);
                  final right = _reportColumn(context);
                  if (constraints.maxWidth >= 720) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 26),
                        Expanded(child: right),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      const SizedBox(height: 18),
                      Divider(color: scheme.outline),
                      const SizedBox(height: 18),
                      right,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Divider(color: scheme.outline),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, 'Assigned by'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: scheme.primaryContainer,
                              child: Text('OM',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary)),
                            ),
                            const SizedBox(width: 8),
                            Text('Office Manager Agent',
                                style: TextStyle(
                                    fontSize: 13, color: scheme.onSurface)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (task.updatedAt != null)
                    Text('Updated ${timeHm(task.updatedAt)}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assignmentColumn(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Description'),
        const SizedBox(height: 8),
        Text(widget.task.description, style: TextStyle(color: scheme.secondary)),
      ],
    );
  }

  Widget _reportColumn(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reports = widget.task.reports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Engineer Report'),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          Text('Awaiting Engineer Report',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
        for (final report in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.description,
                    style: TextStyle(color: scheme.secondary)),
                const SizedBox(height: 10),
                Text('Report by: ${reportAuthorDisplayName(report)}',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                if (report.reportedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Reported ${dateTimeLabel(report.reportedAt)} · MMT',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
      );
}
