import 'package:flutter_test/flutter_test.dart';
import 'package:employee_tasks_mobile/telegram_service.dart';

void main() {
  test('short text stays in one chunk', () {
    expect(chunkText('hello'), <String>['hello']);
    expect(chunkText(''), isEmpty);
  });

  test('splits at the last newline before the limit', () {
    final text = '${'a' * 3990}\nsecond line';
    final chunks = chunkText(text);
    expect(chunks.length, 2);
    expect(chunks.first.length, 3990);
    expect(chunks.last, 'second line');
  });

  test('falls back to a hard split when there is no newline', () {
    final chunks = chunkText('x' * 9000);
    expect(chunks.map((chunk) => chunk.length), <int>[4000, 4000, 1000]);
    expect(chunks.join(), 'x' * 9000);
  });

  test('respects a custom limit', () {
    expect(chunkText('abcdef', limit: 2), <String>['ab', 'cd', 'ef']);
  });
}
