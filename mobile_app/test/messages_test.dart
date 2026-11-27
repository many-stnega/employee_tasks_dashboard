import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:employee_tasks_mobile/message_store.dart';
import 'package:employee_tasks_mobile/screens/messages_page.dart';

import 'fake_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('send is stored locally', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = FakeSmsGateway();
    final store = MessageStore(gateway: gateway);
    await store.load();

    await store.send(' 0912345678 ', 'Hello');
    expect(gateway.sent.single['phone'], '0912345678');
    expect(store.messages.single.body, 'Hello');

    final reloaded = MessageStore(gateway: gateway);
    await reloaded.load();
    expect(reloaded.messages.single.phone, '0912345678');
  });

  testWidgets('messages page shows sent messages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = MessageStore(gateway: FakeSmsGateway());
    await store.load();
    await store.send('0912345678', 'Hello');

    await tester.pumpWidget(MaterialApp(home: MessagesPage(store: store)));
    expect(find.text('0912345678'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}
