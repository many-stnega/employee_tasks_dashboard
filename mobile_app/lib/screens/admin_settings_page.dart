import 'package:material_ui/material_ui.dart';

import '../admin_models.dart';
import '../data_service.dart';
import '../store.dart';

class AdminSettingsPage extends StatefulWidget {
  final TaskStore store;

  const AdminSettingsPage({super.key, required this.store});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  MobileSettings? _settings;
  bool _loading = false;
  bool _saving = false;
  String _message = '';

  late final TextEditingController _adminToken;
  late final TextEditingController _newUserId;
  late final TextEditingController _newUsername;
  late final TextEditingController _newName;
  late final TextEditingController _newGroupId;
  late final TextEditingController _newGroupName;

  final Map<int, TextEditingController> _userUsernameControllers = {};
  final Map<int, TextEditingController> _userNameControllers = {};
  final Map<int, TextEditingController> _groupNameControllers = {};

  @override
  void initState() {
    super.initState();
    _adminToken = TextEditingController(text: widget.store.adminToken);
    _newUserId = TextEditingController();
    _newUsername = TextEditingController();
    _newName = TextEditingController();
    _newGroupId = TextEditingController();
    _newGroupName = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _adminToken.dispose();
    _newUserId.dispose();
    _newUsername.dispose();
    _newName.dispose();
    _newGroupId.dispose();
    _newGroupName.dispose();
    for (final controller in _userUsernameControllers.values) {
      controller.dispose();
    }
    for (final controller in _userNameControllers.values) {
      controller.dispose();
    }
    for (final controller in _groupNameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(
    Map<int, TextEditingController> cache,
    int id,
    String text,
  ) => cache.putIfAbsent(id, () => TextEditingController(text: text));

  DataService _service() => DataService(
        baseUrl: widget.store.serverUrl,
        token: widget.store.mobileToken,
        adminToken: _adminToken.text.trim(),
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    final service = _service();
    try {
      final loaded = await service.fetchSettings();
      if (!mounted) return;
      setState(() => _settings = loaded);
    } on DataServiceException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      service.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;
    await widget.store.setAdminToken(_adminToken.text.trim());
    setState(() {
      _saving = true;
      _message = '';
    });
    final service = _service();
    try {
      final saved = await service.saveSettings(settings);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _message = 'Saved. The bot picks up changes within 10 seconds.';
      });
    } on DataServiceException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      service.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updateUser(int index, UserAccess user) {
    final current = _settings;
    if (current == null) return;
    final users = List<UserAccess>.from(current.users);
    users[index] = user;
    setState(() => _settings = MobileSettings(
          users: users,
          groups: current.groups,
          carryNotifyWeekdays: current.carryNotifyWeekdays,
          counts: current.counts,
        ));
  }

  void _updateGroup(int index, GroupAccess group) {
    final current = _settings;
    if (current == null) return;
    final groups = List<GroupAccess>.from(current.groups);
    groups[index] = group;
    setState(() => _settings = MobileSettings(
          users: current.users,
          groups: groups,
          carryNotifyWeekdays: current.carryNotifyWeekdays,
          counts: current.counts,
        ));
  }

  void _addUser() {
    final current = _settings;
    final id = int.tryParse(_newUserId.text.trim());
    if (current == null || id == null || id <= 0) {
      setState(() => _message = 'Enter a positive Telegram user ID.');
      return;
    }
    if (current.users.any((user) => user.id == id)) {
      setState(() => _message = 'That user ID is already listed.');
      return;
    }
    final users = List<UserAccess>.from(current.users)
      ..add(UserAccess(
        id: id,
        username: _newUsername.text.trim().replaceFirst(RegExp(r'^@'), ''),
        name: _newName.text.trim(),
      ));
    _newUserId.clear();
    _newUsername.clear();
    _newName.clear();
    setState(() {
      _settings = MobileSettings(
        users: users,
        groups: current.groups,
        carryNotifyWeekdays: current.carryNotifyWeekdays,
        counts: current.counts,
      );
      _message = 'User added — tick the roles, then Save.';
    });
  }

  void _addGroup() {
    final current = _settings;
    final id = int.tryParse(_newGroupId.text.trim());
    if (current == null || id == null || id >= 0) {
      setState(() => _message = 'Enter a negative group chat ID.');
      return;
    }
    if (current.groups.any((group) => group.id == id)) {
      setState(() => _message = 'That group is already listed.');
      return;
    }
    final groups = List<GroupAccess>.from(current.groups)
      ..add(GroupAccess(id: id, name: _newGroupName.text.trim()));
    _newGroupId.clear();
    _newGroupName.clear();
    setState(() {
      _settings = MobileSettings(
        users: current.users,
        groups: groups,
        carryNotifyWeekdays: current.carryNotifyWeekdays,
        counts: current.counts,
      );
      _message = 'Group added — tick the roles, then Save.';
    });
  }

  void _toggleDay(String day, bool value) {
    final current = _settings;
    if (current == null) return;
    final days = List<String>.from(current.carryNotifyWeekdays);
    if (value && !days.contains(day)) days.add(day);
    if (!value) days.remove(day);
    days.sort((a, b) => allWeekdays.indexOf(a).compareTo(allWeekdays.indexOf(b)));
    setState(() => _settings = MobileSettings(
          users: current.users,
          groups: current.groups,
          carryNotifyWeekdays: days,
          counts: current.counts,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access & Carry Settings'),
        actions: [
          IconButton(
            tooltip: 'Reload from server',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _adminToken,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mobile admin token',
              helperText: 'Same value as MOBILE_ADMIN_TOKEN on the server.',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => widget.store.setAdminToken(value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.download),
                label: const Text('Load'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: (_saving || settings == null) ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save to server'),
              ),
            ],
          ),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message,
                  style: TextStyle(color: scheme.primary, fontSize: 13)),
            ),
          const SizedBox(height: 24),
          if (_loading && settings == null)
            const Center(child: CircularProgressIndicator()),
          if (settings != null) ...[
            Text('TELEGRAM USERS (${settings.counts['users'] ?? settings.users.length})',
                style: _sectionStyle(context)),
            const SizedBox(height: 8),
            Text(
              'Users can be added before they press /start. A user ID, username and a friendly name are stored together; roles are per user.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < settings.users.length; i++)
              _userCard(context, i, settings.users[i]),
            const SizedBox(height: 12),
            _addUserCard(context),
            const SizedBox(height: 28),
            Text('GROUPS (${settings.counts['groups'] ?? settings.groups.length})',
                style: _sectionStyle(context)),
            const SizedBox(height: 8),
            for (var i = 0; i < settings.groups.length; i++)
              _groupCard(context, i, settings.groups[i]),
            const SizedBox(height: 12),
            _addGroupCard(context),
            const SizedBox(height: 28),
            Text('CARRY NOTIFICATION DAYS', style: _sectionStyle(context)),
            const SizedBox(height: 8),
            Text(
              'Carry itself still runs every day. Telegram notifications are sent only on the checked weekdays.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            Wrap(
              children: [
                for (final day in allWeekdays)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(day.toUpperCase()),
                      selected: settings.carryNotifyWeekdays.contains(day),
                      onSelected: (value) => _toggleDay(day, value),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  TextStyle _sectionStyle(BuildContext context) => TextStyle(
        fontSize: 11,
        letterSpacing: 1.7,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  Widget _userCard(BuildContext context, int index, UserAccess user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('ID ${user.id}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Remove user',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final current = _settings!;
                    final users = List<UserAccess>.from(current.users)
                      ..removeAt(index);
                    setState(() => _settings = MobileSettings(
                          users: users,
                          groups: current.groups,
                          carryNotifyWeekdays: current.carryNotifyWeekdays,
                          counts: current.counts,
                        ));
                  },
                ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Username', hintText: 'di_qing_bai', isDense: true,
              ),
              controller: _controller(
                  _userUsernameControllers, user.id, user.username),
              onChanged: (value) => _updateUser(
                  index, user.copyWith(username: value.replaceFirst(RegExp(r'^@'), ''))),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Display name', hintText: 'Phyu', isDense: true,
              ),
              controller: _controller(_userNameControllers, user.id, user.name),
              onChanged: (value) => _updateUser(index, user.copyWith(name: value)),
            ),
            _role(context, 'Employee (/task_lists, /report)', value: user.standard,
                onChanged: (v) => _updateUser(index, user.copyWith(standard: v))),
            _role(context, 'Manager (assign / end tasks)', value: user.assign,
                onChanged: (v) => _updateUser(index, user.copyWith(assign: v))),
            _role(context, 'Private chat may use commands', value: user.allowedChat,
                onChanged: (v) => _updateUser(index, user.copyWith(allowedChat: v))),
            _role(context, 'Receives report notifications', value: user.reportReceived,
                onChanged: (v) => _updateUser(index, user.copyWith(reportReceived: v))),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(BuildContext context, int index, GroupAccess group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('ID ${group.id}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Remove group',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final current = _settings!;
                    final groups = List<GroupAccess>.from(current.groups)
                      ..removeAt(index);
                    setState(() => _settings = MobileSettings(
                          users: current.users,
                          groups: groups,
                          carryNotifyWeekdays: current.carryNotifyWeekdays,
                          counts: current.counts,
                        ));
                  },
                ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Group name', hintText: 'Team chat', isDense: true,
              ),
              controller: _controller(
                  _groupNameControllers, group.id, group.name),
              onChanged: (value) => _updateGroup(index, group.copyWith(name: value)),
            ),
            _role(context, 'Group members may use bot commands',
                value: group.allowedChat,
                onChanged: (v) => _updateGroup(index, group.copyWith(allowedChat: v))),
            _role(context, 'Report notifications posted here',
                value: group.reportReceived,
                onChanged: (v) => _updateGroup(index, group.copyWith(reportReceived: v))),
          ],
        ),
      ),
    );
  }

  Widget _role(BuildContext context, String label, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: (v) => onChanged(v ?? false),
      );

  Widget _addUserCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _newUserId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Telegram user ID', isDense: true,
              ),
            ),
            TextField(
              controller: _newUsername,
              decoration: const InputDecoration(
                labelText: 'Username (optional)', isDense: true,
              ),
            ),
            TextField(
              controller: _newName,
              decoration: const InputDecoration(
                labelText: 'Display name (optional)', isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addUser,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add user'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addGroupCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _newGroupId,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'New group chat ID (negative)', isDense: true,
              ),
            ),
            TextField(
              controller: _newGroupName,
              decoration: const InputDecoration(
                labelText: 'Group name (optional)', isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.group_add),
              label: const Text('Add group'),
            ),
          ],
        ),
      ),
    );
  }
}
