import 'package:workmanager/workmanager.dart';

import 'format.dart';
import 'reminder_store.dart';
import 'schedule_utils.dart';

const String smsWorkerTask = 'employeeTasksSms';

abstract class SmsJobScheduler {
  Future<void> schedule(Reminder reminder);
  Future<void> cancel(int id);
}

class WorkmanagerSmsJobScheduler implements SmsJobScheduler {
  static String jobName(int id) => 'sms-cron-$id';

  @override
  Future<void> schedule(Reminder reminder) async {
    if (reminder.phone.trim().isEmpty) return;
    final now = DateTime.now().toUtc().add(mmtOffset);
    final next = nextOccurrence(
      reminder.scheduledAt,
      reminder.repeat,
      reminder.weekdays,
      now: now,
    );
    final delay = next.difference(now);
    if (delay.isNegative) return;
    await Workmanager().registerOneOffTask(
      jobName(reminder.id),
      smsWorkerTask,
      initialDelay: delay,
      inputData: <String, dynamic>{'reminder_id': reminder.id},
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  @override
  Future<void> cancel(int id) => Workmanager().cancelByUniqueName(jobName(id));
}
