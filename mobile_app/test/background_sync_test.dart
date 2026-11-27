import 'package:flutter_test/flutter_test.dart';

import 'package:employee_tasks_mobile/background_sync.dart';

void main() {
  test('notifies only when the fetched log changed', () {
    final first = DateTime.utc(2026, 11, 27, 10, 0);
    final second = DateTime.utc(2026, 11, 27, 11, 0);

    expect(shouldNotify(previous: null, updated: first), isTrue);
    expect(shouldNotify(previous: first, updated: second), isTrue);
    expect(shouldNotify(previous: first, updated: first), isFalse);
    expect(shouldNotify(previous: first, updated: null), isFalse);
  });
}
