import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_service.dart';

const String remindersPrefsKey = 'reminders_v1';

class Reminder {
  final int id;
  final String label;
  final DateTime scheduledAt; // stored in UTC
  final String repeat; // once | daily | weekly
  final List<int> weekdays; // DateTime.monday = 1 ... DateTime.sunday = 7
  final List<int> notificationIds;

  const Reminder({
    required this.id,
    required this.label,
    required this.scheduledAt,
    this.repeat = FlutterReminderScheduler.repeatOnce,
    this.weekdays = const <int>[],
    this.notificationIds = const <int>[],
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'scheduled_at': scheduledAt.toIso8601String(),
        'repeat': repeat,
        'weekdays': weekdays,
        'notification_ids': notificationIds,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: (json['id'] as num).toInt(),
        label: (json['label'] as String?) ?? '',
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        repeat: (json['repeat'] as String?) ??
            FlutterReminderScheduler.repeatOnce,
        weekdays: (json['weekdays'] as List<dynamic>?)
                ?.map((value) => (value as num).toInt())
                .toList() ??
            const <int>[],
        notificationIds: (json['notification_ids'] as List<dynamic>?)
                ?.map((value) => (value as num).toInt())
                .toList() ??
            const <int>[],
      );
}

class ReminderStore extends ChangeNotifier {
  ReminderStore({required this.scheduler});

  final ReminderScheduler scheduler;
  SharedPreferences? _prefs;
  List<Reminder> _reminders = <Reminder>[];

  List<Reminder> get reminders => List<Reminder>.unmodifiable(_reminders);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(remindersPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _reminders = decoded
            .whereType<Map>()
            .map((item) => Reminder.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (_) {
        _reminders = <Reminder>[];
      }
    }
    notifyListeners();
  }

  Future<void> add(
    String label,
    DateTime when, {
    required String repeat,
    required List<int> weekdays,
  }) async {
    final text = label.trim();
    if (text.isEmpty) return;
    final id = DateTime.now().microsecondsSinceEpoch % 1000000000;
    final ids = await scheduler.schedule(
      id: id,
      label: text,
      when: when,
      repeat: repeat,
      weekdays: weekdays,
    );
    final reminder = Reminder(
      id: id,
      label: text,
      scheduledAt: when.toUtc(),
      repeat: repeat,
      weekdays: List<int>.from(weekdays),
      notificationIds: ids,
    );
    _reminders = <Reminder>[..._reminders, reminder];
    await _save();
    notifyListeners();
  }

  Future<void> remove(int id) async {
    final reminder = _reminders.firstWhere(
      (item) => item.id == id,
      orElse: () => throw ArgumentError('Unknown reminder id: $id'),
    );
    final ids = reminder.notificationIds.isEmpty
        ? <int>[reminder.id]
        : reminder.notificationIds;
    for (final notificationId in ids) {
      await scheduler.cancel(notificationId);
    }
    _reminders = _reminders.where((item) => item.id != id).toList();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(
      remindersPrefsKey,
      jsonEncode(_reminders.map((item) => item.toJson()).toList()),
    );
  }
}
