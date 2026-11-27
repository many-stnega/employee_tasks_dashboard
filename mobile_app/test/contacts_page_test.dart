import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:employee_tasks_mobile/screens/contacts_page.dart';

import 'fake_repositories.dart';

void main() {
  testWidgets('contacts page can add a contact', (tester) async {
    final repository = FakeContactRepository();
    await tester.pumpWidget(
      MaterialApp(home: ContactsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('No contacts found.'), findsOneWidget);

    await tester.tap(find.byTooltip('Add contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'John Doe');
    await tester.enterText(find.byType(TextField).at(2), '0912345678');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.contacts, hasLength(1));
    expect(repository.contacts.single.name?.first, 'John Doe');
    expect(repository.contacts.single.phones.first.number, '0912345678');
  });
}
