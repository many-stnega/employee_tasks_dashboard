import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee_tasks_mobile/app.dart';
import 'package:employee_tasks_mobile/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the web-style empty log page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = TaskStore();
    await store.load();

    await tester.pumpWidget(TaskApp(store: store));

    expect(find.text('Employee Tasks'), findsOneWidget);
    expect(find.text('DAILY ACTIVITY'), findsOneWidget);
    expect(find.text('No logs for this day'), findsOneWidget);
    expect(find.text('Read only'), findsOneWidget);
  });
}
