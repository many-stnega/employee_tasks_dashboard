import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:employee_tasks_mobile/models.dart';
import 'package:employee_tasks_mobile/widgets/task_card.dart';

void main() {
  testWidgets('card stays compact until Expand details is tapped', (tester) async {
    final task = TaskItem(
      id: '20261127-01',
      title: 'Sample task',
      description: 'Long description only visible when expanded',
      assigneeUsername: 'MKAddison',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: TaskCard(task: task)),
      ),
    ));

    expect(find.text('TASK - 20261127-01'), findsOneWidget);
    expect(find.text('Yu Yu Aung'), findsOneWidget);
    expect(find.text('@MKAddison'), findsNothing);
    expect(find.text('DESCRIPTION'), findsNothing);
    expect(find.byTooltip('Expand details'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand details'));
    await tester.pump();

    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('Long description only visible when expanded'),
        findsOneWidget);
    expect(find.byTooltip('Collapse details'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse details'));
    await tester.pump();
    expect(find.text('DESCRIPTION'), findsNothing);
  });
}
