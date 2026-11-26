import 'package:material_ui/material_ui.dart';

import 'store.dart';
import 'theme.dart';
import 'screens/log_page.dart';
import 'screens/settings_page.dart';

class TaskApp extends StatelessWidget {
  final TaskStore store;

  const TaskApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        title: 'Employee Tasks',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forMode(store.dark),
        home: LogPage(store: store),
        routes: <String, WidgetBuilder>{
          '/settings': (_) => SettingsPage(store: store),
        },
      ),
    );
  }
}
