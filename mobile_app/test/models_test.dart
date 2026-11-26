import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:employee_tasks_mobile/format.dart';
import 'package:employee_tasks_mobile/models.dart';

void main() {
  const sample = '''
  {
    "date": "2026-11-26",
    "updated_at": "2026-11-26T11:21:49+06:30",
    "demo": false,
    "tasks": [
      {
        "id": "20261126-01",
        "created_at": "2026-11-26T11:13:08+06:30",
        "updated_at": "2026-11-26T11:13:08+06:30",
        "task": "Business Angel",
        "assigned_to": {"username": "Di_Qing_Bai", "user_id": 1605652713},
        "description": "Write the daily progress report.",
        "status": "active",
        "employee_reports": [
          {
            "description": "Done",
            "reported_at": "2026-11-26T15:00:00+06:30",
            "reported_by": {"id": 7, "name": "Phyu", "username": "Di_Qing_Bai"}
          }
        ]
      },
      {
        "id": "old-1",
        "repo": {"name": "Legacy task"},
        "assigned_to": "sole_user",
        "description": "Old schema",
        "status": "completed",
        "employee_report": {"description": "Legacy report", "reported_at": "2026-11-25T10:00:00+06:30"}
      }
    ]
  }
  ''';

  test('parses the dashboard schema including legacy fields', () {
    final log = DailyLog.fromJson(Map<String, dynamic>.from(jsonDecode(sample)));
    expect(log.date, '2026-11-26');
    expect(log.tasks.length, 2);
    expect(log.tasks.first.title, 'Business Angel');
    expect(log.tasks.first.assigneeUsername, 'Di_Qing_Bai');
    expect(log.tasks.first.reports.single.description, 'Done');
    expect(engineerLabel(log.tasks.first.assigneeUsername),
        '@Di_Qing_Bai - PhyuPyarChanMyaeKyaw');
    expect(reportAuthorLabel(log.tasks.first.reports.single),
        '@Di_Qing_Bai - PhyuPyarChanMyaeKyaw');
    expect(log.tasks.last.title, 'Legacy task');
    expect(log.tasks.last.assigneeUsername, 'sole_user');
    expect(log.tasks.last.isCompleted, isTrue);
    expect(log.tasks.last.reports.single.description, 'Legacy report');
  });

  test('mergeTask replaces by id and keeps one entry per task', () {
    final log = DailyLog.fromJson(Map<String, dynamic>.from(jsonDecode(sample)));
    final changed = TaskItem(
      id: '20261126-01',
      title: 'Business Angel',
      description: 'Write the daily progress report.',
      status: 'completed',
      updatedAt: DateTime.parse('2026-11-26T18:00:00+06:30'),
    );
    final merged = log.mergeTask(changed);
    expect(merged.tasks.length, 2);
    expect(merged.tasks.first.id, '20261126-01');
    expect(merged.tasks.first.isCompleted, isTrue);
    expect(merged.tasks.first.updatedAt, changed.updatedAt);
  });

  test('report author falls back to name, id or unknown', () {
    expect(reportAuthorLabel(const ReportEntry(description: 'x', authorName: 'Aung')),
        'Aung');
    expect(reportAuthorLabel(const ReportEntry(description: 'x', authorId: '42')),
        'Telegram ID 42');
    expect(reportAuthorLabel(const ReportEntry(description: 'x')),
        'Unknown (not recorded)');
  });
}
