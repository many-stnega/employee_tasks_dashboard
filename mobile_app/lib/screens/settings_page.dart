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
  late final TextEditingController _userId;
  late final TextEditingController _chatId;
  late final TextEditingController _reporter;
  late final TextEditingController _botToken;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: widget.store.serverUrl);
    _apiToken = TextEditingController(text: widget.store.mobileToken);
    _userId = TextEditingController(text: widget.store.telegramUserId);
    _chatId = TextEditingController(text: widget.store.reportChatId);
    _reporter = TextEditingController(text: widget.store.reporterName);
    _botToken = TextEditingController(text: widget.store.botToken);
  }

  @override
  void dispose() {
    _server.dispose();
    _apiToken.dispose();
    _userId.dispose();
    _chatId.dispose();
    _reporter.dispose();
    _botToken.dispose();
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
          Text('REPORT SENDING',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _userId,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Your Telegram user ID (optional)',
              helperText: 'Used as the report author when no username is set.',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.store.setTelegramUserId,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _chatId,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Report chat ID',
              helperText: 'Numeric Telegram chat or user ID that receives reports.',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.store.setReportChatId,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reporter,
            decoration: const InputDecoration(
              labelText: 'Your Telegram username (optional)',
              helperText: 'Shown as the report author.',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.store.setReporterName,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _botToken,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Telegram bot token',
              helperText:
                  'Stored only on this device. Never bundle a production token in the app.',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.store.setBotToken,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A bot token can control the whole bot. Anyone who extracts it from a device can send messages and read updates. Use a dedicated low-privilege reporting bot and rotate its token. Keep the mobile API token private too.',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Task data comes from the server\'s json_data_records only when needed and is cached on this phone. Reports go straight to Telegram.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
