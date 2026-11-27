import 'package:material_ui/material_ui.dart';

import 'contact_repository.dart';
import 'message_store.dart';
import 'reminder_store.dart';
import 'store.dart';
import 'theme.dart';
import 'screens/contacts_page.dart';
import 'screens/log_page.dart';
import 'screens/messages_page.dart';
import 'screens/reminder_page.dart';
import 'screens/settings_page.dart';

class TaskApp extends StatelessWidget {
  final TaskStore store;
  final ReminderStore reminderStore;
  final ContactRepository contactRepository;
  final MessageStore messageStore;

  const TaskApp({
    super.key,
    required this.store,
    required this.reminderStore,
    required this.contactRepository,
    required this.messageStore,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        title: 'Engineer Tasks',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forMode(store.dark),
        home: LogPage(store: store),
        routes: <String, WidgetBuilder>{
          '/settings': (_) => SettingsPage(store: store),
          '/reminders': (_) => ReminderPage(store: reminderStore),
          '/contacts': (_) => ContactsPage(repository: contactRepository),
          '/messages': (_) => MessagesPage(store: messageStore),
        },
      ),
    );
  }
}
