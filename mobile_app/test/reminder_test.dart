import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:employee_tasks_mobile/reminder_store.dart';
import 'package:employee_tasks_mobile/screens/reminder_page.dart';

import 'fake_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('schedules, persists and cancels a reminder', () async {
    SharedPreferences.setMockInitialValues({});
    final scheduler = FakeScheduler();
    final store = ReminderStore(scheduler: scheduler);
    await store.load();

    await store.add(
      '  Standup  ',
      DateTime(2026, 11, 28, 9, 30),
      repeat: 'daily',
      weekdays: const <int>[],
    );
    expect(store.reminders, hasLength(1));
    expect(store.reminders.single.label, 'Standup');
    expect(scheduler.scheduled.single['label'], 'Standup');
    expect(scheduler.scheduled.single['repeat'], 'daily');

    final reloaded = ReminderStore(scheduler: scheduler);
    await reloaded.load();
    expect(reloaded.reminders.single.label, 'Standup');
    expect(reloaded.reminders.single.repeat, 'daily');

    await reloaded.remove(reloaded.reminders.single.id);
    expect(reloaded.reminders, isEmpty);
    expect(scheduler.cancelled, hasLength(1));
  });

  test('weekly reminders get one notification id per weekday', () async {
    SharedPreferences.setMockInitialValues({});
    final scheduler = FakeScheduler();
    final store = ReminderStore(scheduler: scheduler);
    await store.load();

    await store.add(
      'Team meeting',
      DateTime(2026, 11, 30, 10, 0),
      repeat: 'weekly',
      weekdays: const <int>[DateTime.monday, DateTime.wednesday],
    );

    expect(scheduler.scheduled.single['ids'], hasLength(2));
    expect(store.reminders.single.notificationIds, hasLength(2));
    await store.remove(store.reminders.single.id);
    expect(scheduler.cancelled, hasLength(2));
  });

  testWidgets('reminder page can set an alarm', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final scheduler = FakeScheduler();
    final store = ReminderStore(scheduler: scheduler);
    await store.load();

    await tester.pumpWidget(MaterialApp(home: ReminderPage(store: store)));
    expect(find.text('NEW JOB'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('No jobs yet.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Drink water');
    await tester.tap(find.byIcon(Icons.alarm_add));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled, hasLength(1));
    expect(find.text('Drink water'), findsOneWidget);
  });
}
