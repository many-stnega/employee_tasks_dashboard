import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../sync_service.dart';
import '../widgets/report_sheet.dart';
import '../widgets/task_card.dart';

class LogPage extends StatefulWidget {
  final TaskStore store;

  const LogPage({super.key, required this.store});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  late DateTime _month;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(mmtOffset);
    _month = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final message = await syncLatest(widget.store);
    if (!mounted) return;
    await widget.store.setNotice(message);
    setState(() => _syncing = false);
  }

  Future<void> _chooseDate() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DateSheet(
        store: widget.store,
        initialMonth: _month,
      ),
    );
    if (chosen != null) {
      await widget.store.setSelectedDate(chosen);
      if (!widget.store.isCached(chosen)) {
        final message = await syncDay(widget.store, chosen);
        if (mounted) await widget.store.setNotice(message);
      }
    }
  }

  Future<void> _openReport(TaskItem task) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(task: task, store: widget.store),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final log = widget.store.current;
        final isToday = widget.store.selectedDate == todayKey();
        final tasks = [...log.tasks]
          ..sort((a, b) {
            final aTime = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Center(
                    child: Text('✓',
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee Tasks',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    Text('OFFICE MANAGER',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Sync from server',
                icon: const Icon(Icons.sync),
                onPressed: _syncing ? null : _refresh,
              ),
              IconButton(
                tooltip: widget.store.dark ? 'Light mode' : 'Dark mode',
                icon: Icon(widget.store.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => widget.store.setDark(!widget.store.dark),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DAILY ACTIVITY',
                                style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.7,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(
                              isToday ? 'Today’s log' : 'Daily log',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(prettyDate(widget.store.selectedDate),
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Read only',
                            style: TextStyle(
                                fontSize: 12, color: scheme.primary)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton.icon(
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(isToday
                        ? 'Today’s log'
                        : 'Jump to ${prettyDate(widget.store.selectedDate)}'),
                  ),
                ),
                if (log.demo)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      'Sample preview data · These are illustrative assignments, not live employee records.',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Text(
                        '${tasks.length} task log${tasks.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      if (log.updatedAt != null)
                        Text('Last update ${timeHm(log.updatedAt)} · MMT',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (widget.store.notice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.notifications_active_outlined,
                          color: scheme.primary),
                      title: Text(widget.store.notice,
                          style: TextStyle(fontSize: 13, color: scheme.primary)),
                    ),
                  ),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 48, color: scheme.onSurfaceVariant),
                                const SizedBox(height: 12),
                                Text('No logs for this day',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 6),
                                Text(
                                  'Choose another date, or sync from the server.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _chooseDate,
                                  icon: const Icon(Icons.calendar_today),
                                  label: const Text('Choose date'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) => TaskCard(
                              task: tasks[index],
                              onReport: () => _openReport(tasks[index]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateSheet extends StatefulWidget {
  final TaskStore store;
  final DateTime initialMonth;

  const _DateSheet({
    required this.store,
    required this.initialMonth,
  });

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }
  Future<void> _pickWithSystem() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse('${widget.store.selectedDate}T12:00:00') ??
          DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) {
      final key =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      Navigator.of(context).pop(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday % 7;
    final count = DateTime(
      _month.year,
      _month.month + 1,
      0,
    ).day;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _month =
                      DateTime(_month.year, _month.month - 1, 1)),
                ),
                Text(DateFormat.yMMMM('en_US').format(_month),
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _month =
                      DateTime(_month.year, _month.month + 1, 1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa',
              ].map((day) => SizedBox(width: 36, child: Text(day, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))))).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              children: [
                for (var i = 0; i < leading; i++)
                  const SizedBox(width: 42, height: 42),
                for (var day = 1; day <= count; day++)
                  _dayButton(day, scheme),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickWithSystem,
              icon: const Icon(Icons.date_range),
              label: const Text('Jump to date'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayButton(int day, ColorScheme scheme) {
    final key =
        '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final selected = key == widget.store.selectedDate;
    final today = key == todayKey();
    return SizedBox(
      width: 42,
      height: 42,
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(key),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: selected ? scheme.primaryContainer : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: today ? BorderSide(color: scheme.primary) : BorderSide.none,
          ),
        ),
        child: Text('$day',
            style: TextStyle(
                color: selected ? scheme.primary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}
