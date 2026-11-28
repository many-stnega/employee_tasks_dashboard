import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'data_service.dart';
import 'message_service.dart';
import 'reminder_service.dart';
import 'reminder_store.dart';
import 'sms_job_service.dart';
import 'store.dart';
import 'sync_service.dart';

const String backgroundSyncTask = 'employeeTasksFetch';

Future<bool> _runSmsJob(
  FlutterLocalNotificationsPlugin notifications,
  Map<String, dynamic>? inputData,
) async {
  try {
    final id = (inputData?['reminder_id'] as num?)?.toInt();
    if (id == null) return true;
    final store = ReminderStore(
      scheduler: FlutterReminderScheduler(notifications),
    );
    await store.load();
    Reminder? job;
    for (final item in store.reminders) {
      if (item.id == id) {
        job = item;
        break;
      }
    }
    if (job == null || job.phone.trim().isEmpty) return true;

    final body = job.taskTitle.isEmpty
        ? job.label
        : '${job.label}\nTask: ${job.taskTitle}${job.taskId.isEmpty ? '' : ' (${job.taskId})'}';
    await DeviceSmsGateway().send(phone: job.phone, body: body);
    await notifications.show(
      id: 1000000 + (id % 100000),
      title: 'Engineer Tasks',
      body: 'SMS cron job sent to ${job.phone}.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          FlutterReminderScheduler.channelId,
          FlutterReminderScheduler.channelName,
          channelDescription: FlutterReminderScheduler.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    if (job.repeat != FlutterReminderScheduler.repeatOnce) {
      await WorkmanagerSmsJobScheduler().schedule(job);
    }
    return true;
  } catch (_) {
    return true;
  }
}

/// True when a fresh fetch brought in a different daily log.
bool shouldNotify({required DateTime? previous, required DateTime? updated}) =>
    updated != null && previous != updated;

/// Top-level callback for Android WorkManager. Runs even when the app is not
/// open (WorkManager owns the schedule), fetches the newest daily log and
/// raises a local notification only when the data actually changed.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      if (task == smsWorkerTask) {
        return await _runSmsJob(notifications, inputData);
      }
      if (task != backgroundSyncTask) return true;

      final store = TaskStore();
      await store.load();
      if (store.serverUrl.isEmpty || store.mobileToken.isEmpty) return true;

      final service = DataService(
        baseUrl: store.serverUrl,
        token: store.mobileToken,
      );
      late final List<String> dates;
      try {
        dates = await service.fetchDates();
      } finally {
        service.close();
      }
      if (dates.isEmpty) return true;

      final target = dates.contains(todayKey()) ? todayKey() : dates.last;
      final previous = store.cachedDay(target)?.updatedAt;
      final message = await syncDay(store, target);
      if (!message.startsWith('Synced')) return true;

      final updated = store.cachedDay(target)?.updatedAt;
      if (!shouldNotify(previous: previous, updated: updated)) return true;

      await notifications.show(
        id: 999999,
        title: 'Engineer Tasks',
        body: 'New task data for $target is available.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            FlutterReminderScheduler.channelId,
            FlutterReminderScheduler.channelName,
            channelDescription: FlutterReminderScheduler.channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      return true;
    } catch (_) {
      // Returning true avoids WorkManager retry storms on bad config.
      return true;
    }
  });
}
