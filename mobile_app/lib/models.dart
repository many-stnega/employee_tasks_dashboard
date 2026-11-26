import 'dart:convert';

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int? _integer(Object? value) => switch (value) {
      int() => value,
      String() => int.tryParse(value),
      _ => null,
    };

DateTime? _date(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value.replaceFirst('Z', '+00:00'));
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
    : <Map<String, dynamic>>[];

class ReportEntry {
  final String description;
  final DateTime? reportedAt;
  final String? authorId;
  final String? authorName;
  final String? authorUsername;

  const ReportEntry({
    required this.description,
    this.reportedAt,
    this.authorId,
    this.authorName,
    this.authorUsername,
  });

  factory ReportEntry.fromJson(Map<String, dynamic> json) {
    final author = _map(json['reported_by']) ?? const <String, dynamic>{};
    return ReportEntry(
      description: _string(json['description']) ?? '',
      reportedAt: _date(json['reported_at']),
      authorId: _integer(author['id'])?.toString(),
      authorName: _string(author['name']),
      authorUsername: _string(author['username']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'description': description,
        if (reportedAt != null) 'reported_at': reportedAt!.toIso8601String(),
        if (authorId != null || authorName != null || authorUsername != null)
          'reported_by': <String, dynamic>{
            if (authorId != null) 'id': int.tryParse(authorId!) ?? authorId,
            if (authorName != null) 'name': authorName,
            if (authorUsername != null) 'username': authorUsername,
          },
      };
}

class TaskItem {
  final String id;
  final String title;
  final String? assigneeUsername;
  final String? assigneeName;
  final String? assigneeUserId;
  final String description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ReportEntry> reports;

  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    this.assigneeUsername,
    this.assigneeName,
    this.assigneeUserId,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.reports = const <ReportEntry>[],
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final rawAssigned = json['assigned_to'];
    final assigned = _map(rawAssigned);
    final legacyRepo = _map(json['repo']);
    final legacyName = _string(_map(json['employee_report'])?['description']);
    final rawReports = <Map<String, dynamic>>[
      ..._maps(json['employee_reports']),
      if (legacyName != null) <String, dynamic>{'description': legacyName},
    ];
    return TaskItem(
      id: _string(json['id']) ?? '',
      title: _string(json['task']) ??
          _string(legacyRepo?['name']) ??
          'Untitled task',
      description: _string(json['description']) ?? '',
      assigneeUsername: _string(assigned?['username']) ??
          (rawAssigned is String && rawAssigned.isNotEmpty ? rawAssigned : null),
      assigneeName: _string(assigned?['name']),
      assigneeUserId: _integer(assigned?['user_id'])?.toString(),
      status: _string(json['status']) ?? 'active',
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      reports: rawReports.map(ReportEntry.fromJson).toList(),
    );
  }

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'task': title,
        'assigned_to': <String, dynamic>{
          if (assigneeUsername != null) 'username': assigneeUsername,
          if (assigneeName != null) 'name': assigneeName,
          if (assigneeUserId != null) 'user_id': int.tryParse(assigneeUserId!) ?? assigneeUserId,
        },
        'description': description,
        'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'employee_reports': reports.map((report) => report.toJson()).toList(),
      };
}

class DailyLog {
  final String date;
  final DateTime? updatedAt;
  final bool demo;
  final List<TaskItem> tasks;

  const DailyLog({
    required this.date,
    required this.tasks,
    this.updatedAt,
    this.demo = false,
  });

  factory DailyLog.empty(String date) =>
      DailyLog(date: date, tasks: const <TaskItem>[]);

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    final date = _string(json['date']) ?? '';
    return DailyLog(
      date: date,
      updatedAt: _date(json['updated_at']),
      demo: json['demo'] == true,
      tasks: _maps(json['tasks']).map(TaskItem.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'updated_at': updatedAt?.toIso8601String(),
        'demo': demo,
        'tasks': tasks.map((task) => task.toJson()).toList(),
      };

  DailyLog mergeTask(TaskItem task) {
    final merged = <String, TaskItem>{for (final item in tasks) item.id: item};
    merged[task.id] = task;
    final items = merged.values.toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return DailyLog(
      date: date,
      updatedAt: DateTime.now(),
      demo: demo,
      tasks: items,
    );
  }

  DailyLog replaceWith(DailyLog other) => DailyLog(
        date: date,
        updatedAt: other.updatedAt ?? DateTime.now(),
        demo: other.demo,
        tasks: other.tasks,
      );
}

DailyLog parseDailyLog(String source) => DailyLog.fromJson(
      Map<String, dynamic>.from(jsonDecode(source) as Map),
);
