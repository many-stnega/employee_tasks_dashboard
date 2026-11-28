import 'package:flutter_test/flutter_test.dart';
import 'package:employee_tasks_mobile/admin_models.dart';

void main() {
  const payload = <String, dynamic>{
    'users': [
      {
        'id': 123,
        'username': 'di_qing_bai',
        'name': 'Phyu',
        'roles': {
          'standard': true,
          'assign': false,
          'allowed_chat': true,
          'report_received': false,
        },
      }
    ],
    'groups': [
      {
        'id': -100123,
        'name': 'Team',
        'roles': {'allowed_chat': true, 'report_received': false},
      }
    ],
    'carry_notify_weekdays': ['mon', 'wed', 'fri'],
    'counts': {'users': 1, 'groups': 1},
  };

  test('parses users, groups and carry weekdays with counts', () {
    final settings = MobileSettings.fromJson(payload);
    expect(settings.users.single.id, 123);
    expect(settings.users.single.name, 'Phyu');
    expect(settings.users.single.standard, isTrue);
    expect(settings.users.single.assign, isFalse);
    expect(settings.groups.single.id, -100123);
    expect(settings.groups.single.allowedChat, isTrue);
    expect(settings.carryNotifyWeekdays, ['mon', 'wed', 'fri']);
    expect(settings.counts['users'], 1);
  });

  test('toJson omits read-only counts', () {
    final settings = MobileSettings.fromJson(payload);
    final json = settings.toJson();
    expect(json.containsKey('counts'), isFalse);
    expect(json['users'].first['roles']['allowed_chat'], isTrue);
  });

  test('copyWith keeps the user id and changes one role', () {
    final user = UserAccess.fromJson(payload['users'][0] as Map<String, dynamic>);
    final changed = user.copyWith(assign: true);
    expect(changed.id, user.id);
    expect(changed.standard, isTrue);
    expect(changed.assign, isTrue);
  });
}
