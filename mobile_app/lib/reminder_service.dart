import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

/// Abstraction so tests can run without the real notification plugin.
abstract class ReminderScheduler {
  Future<void> initialize();

  /// Returns every notification id that was scheduled, so the store can
  /// cancel them all later (weekly alarms need one id per weekday).
  Future<List<int>> schedule({
    required int id,
    required String label,
    required DateTime when,
    required String repeat,
    required List<int> weekdays,
  });

  Future<void> cancel(int id);
}

class FlutterReminderScheduler implements ReminderScheduler {
  FlutterReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'employee_tasks_reminders';
  static const String channelName = 'Reminders';
  static const String channelDescription = 'Alarms set from this app';
  static const String locationName = 'Asia/Yangon';
  static const String repeatOnce = 'once';
  static const String repeatDaily = 'daily';
  static const String repeatWeekly = 'weekly';

  @override
  Future<void> initialize() async {
    tzd.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(locationName));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    ));
    await android?.requestNotificationsPermission();
    if (android != null &&
        await android.canScheduleExactNotifications() != true) {
      await android.requestExactAlarmsPermission();
    }
  }

  @override
  Future<List<int>> schedule({
    required int id,
    required String label,
    required DateTime when,
    required String repeat,
    required List<int> weekdays,
  }) async {
    final location = tz.getLocation(locationName);
    final now = tz.TZDateTime.now(location);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final ids = <int>[];

    if (repeat == repeatWeekly && weekdays.isNotEmpty) {
      // One request per weekday: dayOfWeekAndTime matches a single weekday.
      for (final weekday in weekdays) {
        var scheduled = tz.TZDateTime(
            location, now.year, now.month, now.day, when.hour, when.minute);
        scheduled = scheduled.add(Duration(days: (weekday - scheduled.weekday) % 7));
        if (!scheduled.isAfter(now)) {
          scheduled = scheduled.add(const Duration(days: 7));
        }
        final notificationId = id + weekday * 1000000;
        await _plugin.zonedSchedule(
          id: notificationId,
          title: 'Cron Job',
          body: label,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        ids.add(notificationId);
      }
      return ids;
    }

    if (repeat == repeatDaily) {
      var scheduled = tz.TZDateTime(
          location, now.year, now.month, now.day, when.hour, when.minute);
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: id,
        title: 'Cron Job',
        body: label,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return <int>[id];
    }

    // One-shot at the exact picked date and time.
    var scheduled = tz.TZDateTime(
        location, when.year, when.month, when.day, when.hour, when.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: id,
      title: 'Cron Job',
      body: label,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return <int>[id];
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
