import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:employee_tasks_mobile/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('purges legacy report-sending settings on load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bot_token_v1': 'legacy-token',
      'report_chat_id_v1': '12345',
      'reporter_name_v1': 'legacy-user',
      'telegram_user_id_v1': '67890',
    });

    final store = TaskStore();
    await store.load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('bot_token_v1'), isNull);
    expect(prefs.getString('report_chat_id_v1'), isNull);
    expect(prefs.getString('reporter_name_v1'), isNull);
    expect(prefs.getString('telegram_user_id_v1'), isNull);
  });
}
