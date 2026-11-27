import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../reminder_service.dart';
import '../reminder_store.dart';

class ReminderPage extends StatefulWidget {
  final ReminderStore store;

  const ReminderPage({super.key, required this.store});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final TextEditingController _label = TextEditingController();
  late DateTime _when;
  String _repeat = FlutterReminderScheduler.repeatOnce;
  final Set<int> _weekdays = <int>{};
  bool _saving = false;

  static const Map<int, String> _weekdayNames = <int, String>{
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };

  String _repeatText(Reminder reminder) {
    if (reminder.repeat == FlutterReminderScheduler.repeatDaily) {
      return 'Daily';
    }
    if (reminder.repeat == FlutterReminderScheduler.repeatWeekly) {
      final days = reminder.weekdays
          .map((day) => _weekdayNames[day] ?? '$day')
          .join(', ');
      return 'Weekly: $days';
    }
    return 'Once';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(mmtOffset);
    _when = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_when.year, _when.month, _when.day),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _when = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _when.hour,
            _when.minute,
          ));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _when.hour, minute: _when.minute),
    );
    if (picked != null) {
      setState(() => _when = DateTime(
            _when.year,
            _when.month,
            _when.day,
            picked.hour,
            picked.minute,
          ));
    }
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a job name.')),
      );
      return;
    }
    if (_repeat == FlutterReminderScheduler.repeatWeekly &&
        _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one weekday.')),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.store.add(
      _label.text,
      _when,
      repeat: _repeat,
      weekdays: _weekdays.toList()..sort(),
    );
    if (!mounted) return;
    _label.clear();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Job scheduled for ${dateTimeLabel(_when)} · MMT ($_repeat)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final dateText =
            '${_when.year}-${_when.month.toString().padLeft(2, '0')}-${_when.day.toString().padLeft(2, '0')}';
        final timeText =
            '${_when.hour.toString().padLeft(2, '0')}:${_when.minute.toString().padLeft(2, '0')}';
        return Scaffold(
          appBar: AppBar(title: const Text('Cron Jobs')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('NEW JOB',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Job name',
                  helperText: 'Shown in the notification',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(dateText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(timeText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _repeat,
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: FlutterReminderScheduler.repeatOnce,
                    child: Text('Once'),
                  ),
                  DropdownMenuItem(
                    value: FlutterReminderScheduler.repeatDaily,
                    child: Text('Every day'),
                  ),
                  DropdownMenuItem(
                    value: FlutterReminderScheduler.repeatWeekly,
                    child: Text('Selected weekdays'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _repeat = value);
                },
              ),
              if (_repeat == FlutterReminderScheduler.repeatWeekly) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final entry in _weekdayNames.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _weekdays.contains(entry.key),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _weekdays.add(entry.key);
                          } else {
                            _weekdays.remove(entry.key);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.alarm_add),
                label: Text(_saving ? 'Scheduling…' : 'Set job'),
              ),
              const SizedBox(height: 28),
              Text('SCHEDULED',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              if (widget.store.reminders.isEmpty)
                Text('No jobs yet.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13)),
              for (final reminder in widget.store.reminders)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(reminder.label),
                    subtitle: Text(
                      '${dateTimeLabel(reminder.scheduledAt)} · MMT · ${_repeatText(reminder)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Cancel job',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => widget.store.remove(reminder.id),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Jobs use Myanmar time (MMT). Daily and weekly jobs keep running on later days; notifications appear even when the app is closed.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}
