import 'package:material_ui/material_ui.dart';

import '../store.dart';
import '../sync_service.dart';

class SettingsPage extends StatefulWidget {
  final TaskStore store;

  const SettingsPage({super.key, required this.store});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _server;
  late final TextEditingController _apiToken;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: widget.store.serverUrl);
    _apiToken = TextEditingController(text: widget.store.mobileToken);
  }

  @override
  void dispose() {
    _server.dispose();
    _apiToken.dispose();
    super.dispose();
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final message = await syncLatest(widget.store);
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('SERVER DATA',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _server,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Dashboard server URL',
              helperText: 'Example: https://dashboard.example.com',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.store.setServerUrl,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiToken,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mobile API token',
              helperText: 'Same value as MOBILE_API_TOKEN on the server.',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.store.setMobileToken,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_syncing ? 'Syncing…' : 'Sync from server'),
          ),
          if (widget.store.notice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.store.notice,
                  style: TextStyle(fontSize: 13, color: scheme.primary)),
            ),
          const SizedBox(height: 24),
          Text(
            'Task data comes from the server\'s json_data_records only when needed and is cached on this phone.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Text('APPEARANCE',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle:
                Text(widget.store.dark ? 'Dark theme' : 'Light theme'),
            secondary: Icon(
                widget.store.dark ? Icons.dark_mode : Icons.light_mode),
            value: widget.store.dark,
            onChanged: (value) async {
              await widget.store.setDark(value);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
