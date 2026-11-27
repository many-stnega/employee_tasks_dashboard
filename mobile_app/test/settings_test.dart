import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:employee_tasks_mobile/screens/settings_page.dart';
import 'package:employee_tasks_mobile/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme mode is changed from Settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = TaskStore();
    await store.load();

    await tester.pumpWidget(MaterialApp(home: SettingsPage(store: store)));
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(store.dark, isTrue);
    expect(find.text('Dark theme'), findsOneWidget);
  });
}
