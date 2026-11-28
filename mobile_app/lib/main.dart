import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'app_defaults.dart';
import 'background_sync.dart';
import 'contact_repository.dart';
import 'message_service.dart';
import 'message_store.dart';
import 'reminder_service.dart';
import 'reminder_store.dart';
import 'sms_job_service.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TaskStore();
  await store.applyDefaults(
    serverUrl: defaultServerUrl,
    mobileToken: defaultMobileToken,
    adminToken: defaultAdminToken,
  );
  await store.load();
  final notifications = FlutterLocalNotificationsPlugin();
  final scheduler = FlutterReminderScheduler(notifications);
  await scheduler.initialize();
  final reminderStore = ReminderStore(scheduler: scheduler);
  await reminderStore.load();
  final messageStore = MessageStore(gateway: DeviceSmsGateway());
  await messageStore.load();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'employee-tasks-fetch',
    backgroundSyncTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Re-arm SMS cron jobs after a restart.
  final smsJobs = WorkmanagerSmsJobScheduler();
  for (final job in reminderStore.reminders) {
    if (job.phone.isNotEmpty) await smsJobs.schedule(job);
  }

  runApp(TaskApp(
    store: store,
    reminderStore: reminderStore,
    contactRepository: NativeContactRepository(),
    messageStore: messageStore,
    smsJobScheduler: smsJobs,
  ));
}
