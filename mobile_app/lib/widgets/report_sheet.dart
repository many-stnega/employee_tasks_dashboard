import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../telegram_service.dart';

class ReportSheet extends StatefulWidget {
  final TaskItem task;
  final TaskStore store;

  const ReportSheet({super.key, required this.task, required this.store});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final description = _controller.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report cannot be empty.')),
      );
      return;
    }
    setState(() => _sending = true);
    // Same message shape as backend_python/bot.py:notify_report_received.
    final reporter = widget.store.reporterName.isNotEmpty
        ? engineerLabel(widget.store.reporterName)
        : (widget.store.telegramUserId.isNotEmpty
            ? 'Telegram ID ${widget.store.telegramUserId}'
            : 'Unknown (not recorded)');
    final message = <String>[
      '📝 Task report received',
      'Task ID: ${widget.task.id}',
      'Task: ${widget.task.title}',
      'Assigned to: ${engineerLabel(widget.task.assigneeUsername, fallbackName: widget.task.assigneeName)}',
      'Reported by: $reporter',
      '',
      description,
    ].join('\n');

    final result = await sendReport(
      token: widget.store.botToken,
      chatId: widget.store.reportChatId,
      text: message,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok
            ? 'Report sent to Telegram.'
            : 'Report was not sent: ${result.error}'),
      ),
    );
    if (result.ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20, bottom: 20 + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Report for ${widget.task.title}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Sent directly to Telegram; no backend call is made.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Your report',
              hintText: 'What was completed today?',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Sending…' : 'Send report'),
          ),
        ],
      ),
    );
  }
}
