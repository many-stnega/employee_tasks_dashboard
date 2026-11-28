const List<String> allWeekdays = <String>[
  'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun',
];

class UserAccess {
  final int id;
  final String username;
  final String name;
  final bool standard;
  final bool assign;
  final bool allowedChat;
  final bool reportReceived;

  const UserAccess({
    required this.id,
    this.username = '',
    this.name = '',
    this.standard = false,
    this.assign = false,
    this.allowedChat = false,
    this.reportReceived = false,
  });

  factory UserAccess.fromJson(Map<String, dynamic> json) {
    final roles = _map(json['roles']);
    return UserAccess(
      id: _int(json['id']) ?? 0,
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      standard: roles['standard'] == true,
      assign: roles['assign'] == true,
      allowedChat: roles['allowed_chat'] == true,
      reportReceived: roles['report_received'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'username': username,
        'name': name,
        'roles': <String, dynamic>{
          'standard': standard,
          'assign': assign,
          'allowed_chat': allowedChat,
          'report_received': reportReceived,
        },
      };

  UserAccess copyWith({
    String? username,
    String? name,
    bool? standard,
    bool? assign,
    bool? allowedChat,
    bool? reportReceived,
  }) => UserAccess(
        id: id,
        username: username ?? this.username,
        name: name ?? this.name,
        standard: standard ?? this.standard,
        assign: assign ?? this.assign,
        allowedChat: allowedChat ?? this.allowedChat,
        reportReceived: reportReceived ?? this.reportReceived,
      );
}

class GroupAccess {
  final int id;
  final String name;
  final bool allowedChat;
  final bool reportReceived;

  const GroupAccess({
    required this.id,
    this.name = '',
    this.allowedChat = false,
    this.reportReceived = false,
  });

  factory GroupAccess.fromJson(Map<String, dynamic> json) {
    final roles = _map(json['roles']);
    return GroupAccess(
      id: _int(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      allowedChat: roles['allowed_chat'] == true,
      reportReceived: roles['report_received'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'roles': <String, dynamic>{
          'allowed_chat': allowedChat,
          'report_received': reportReceived,
        },
      };

  GroupAccess copyWith({
    String? name,
    bool? allowedChat,
    bool? reportReceived,
  }) => GroupAccess(
        id: id,
        name: name ?? this.name,
        allowedChat: allowedChat ?? this.allowedChat,
        reportReceived: reportReceived ?? this.reportReceived,
      );
}

class MobileSettings {
  final List<UserAccess> users;
  final List<GroupAccess> groups;
  final List<String> carryNotifyWeekdays;
  final Map<String, int> counts;

  const MobileSettings({
    this.users = const <UserAccess>[],
    this.groups = const <GroupAccess>[],
    this.carryNotifyWeekdays = allWeekdays,
    this.counts = const <String, int>{},
  });

  factory MobileSettings.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    final rawGroups = json['groups'];
    final rawDays = json['carry_notify_weekdays'];
    final rawCounts = json['counts'];
    return MobileSettings(
      users: rawUsers is List
          ? rawUsers
              .whereType<Map>()
              .map((item) => UserAccess.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <UserAccess>[],
      groups: rawGroups is List
          ? rawGroups
              .whereType<Map>()
              .map((item) => GroupAccess.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <GroupAccess>[],
      carryNotifyWeekdays: rawDays is List
          ? rawDays.whereType<String>().toList()
          : List<String>.from(allWeekdays),
      counts: rawCounts is Map
          ? Map<String, int>.from(
              rawCounts.map((key, value) => MapEntry(key.toString(), _int(value) ?? 0)))
          : <String, int>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'users': users.map((user) => user.toJson()).toList(),
        'groups': groups.map((group) => group.toJson()).toList(),
        'carry_notify_weekdays': carryNotifyWeekdays,
      };
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int? _int(Object? value) => switch (value) {
      int() => value,
      String() => int.tryParse(value),
      _ => null,
    };
