import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'data_service.dart';
import 'reminder_service.dart';
import 'store.dart';
import 'sync_service.dart';

const String backgroundSyncTask = 'employeeTasksFetch';

/// True when a fresh fetch brought in a different daily log.
bool shouldNotify({required DateTime? previous, required DateTime? updated}) =>
    updated != null && previous != updated;

/// Top-level callback for Android WorkManager. Runs even when the app is not
/// open (WorkManager owns the schedule), fetches the newest daily log and
/// raises a local notification only when the data actually changed.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundSyncTask) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

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
