import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee_tasks_mobile/app.dart';
import 'package:employee_tasks_mobile/store.dart';
import 'package:employee_tasks_mobile/message_store.dart';
import 'package:employee_tasks_mobile/reminder_store.dart';

import 'fake_repositories.dart';
import 'fake_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the web-style empty log page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = TaskStore();
    await store.load();
    final reminderStore = ReminderStore(scheduler: FakeScheduler());
    await reminderStore.load();
    final messageStore = MessageStore(gateway: FakeSmsGateway());
    await messageStore.load();

    await tester.pumpWidget(
      TaskApp(
        store: store,
        reminderStore: reminderStore,
        contactRepository: FakeContactRepository(),
        messageStore: messageStore,
      ),
    );

    expect(find.text('Engineer Tasks'), findsOneWidget);
    expect(find.byTooltip('Choose date'), findsOneWidget);
    expect(find.text('No logs for this day'), findsOneWidget);
    expect(find.text('Read only'), findsOneWidget);
  });

  testWidgets('left drawer navigates to reminders', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = TaskStore();
    await store.load();
    final reminderStore = ReminderStore(scheduler: FakeScheduler());
    await reminderStore.load();
    final messageStore = MessageStore(gateway: FakeSmsGateway());
    await messageStore.load();

    await tester.pumpWidget(
      TaskApp(
        store: store,
        reminderStore: reminderStore,
        contactRepository: FakeContactRepository(),
        messageStore: messageStore,
      ),
    );

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Cron Jobs'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);

    await tester.tap(find.text('Cron Jobs'));
    await tester.pumpAndSettle();
    expect(find.text('NEW JOB'), findsOneWidget);
  });
}
