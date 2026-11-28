import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee_tasks_mobile/activity_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('entries are stored newest first and survive a reload', () async {
    final log = ActivityLogStore();
    await log.load();
    await log.add('sync', 'Synced today');
    await log.add('sms', 'SMS sent to 09xxx');

    expect(log.entries.length, 2);
    expect(log.entries.first.source, 'sms');
    expect(log.entries.last.message, 'Synced today');

    final reloaded = ActivityLogStore();
    await reloaded.load();
    expect(reloaded.entries.length, 2);
    expect(reloaded.entries.first.message, 'SMS sent to 09xxx');
  });

  test('clear removes every local entry', () async {
    final log = ActivityLogStore();
    await log.load();
    await log.add('app', 'App started.');
    await log.clear();
    expect(log.entries, isEmpty);

    final reloaded = ActivityLogStore();
    await reloaded.load();
    expect(reloaded.entries, isEmpty);
  });

  test('keeps only the newest 500 entries', () async {
    final log = ActivityLogStore();
    await log.load();
    for (var i = 0; i < 505; i++) {
      await log.add('app', 'event $i');
    }
    expect(log.entries.length, maxActivityEntries);
    expect(log.entries.first.message, 'event 504');
  });
}
