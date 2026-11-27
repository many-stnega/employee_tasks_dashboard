import 'package:employee_tasks_mobile/reminder_service.dart';

class FakeScheduler implements ReminderScheduler {
  final List<Map<String, dynamic>> scheduled = <Map<String, dynamic>>[];
  final List<int> cancelled = <int>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<List<int>> schedule({
    required int id,
    required String label,
    required DateTime when,
    required String repeat,
    required List<int> weekdays,
  }) async {
    final ids = repeat == 'weekly'
        ? weekdays.map((day) => id + day * 1000000).toList()
        : <int>[id];
    scheduled.add(<String, dynamic>{
      'id': id,
      'label': label,
      'when': when,
      'repeat': repeat,
      'weekdays': weekdays,
      'ids': ids,
    });
    return ids;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}
