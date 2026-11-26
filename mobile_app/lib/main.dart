import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TaskStore();
  await store.load();
  runApp(TaskApp(store: store));
}
