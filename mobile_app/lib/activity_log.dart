import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String activityLogPrefsKey = 'activity_log_v1';
const int maxActivityEntries = 500;

class ActivityLogEntry {
  final DateTime at;
  final String source;
  final String message;

  const ActivityLogEntry({
    required this.at,
    required this.source,
    required this.message,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'at': at.toIso8601String(),
        'source': source,
        'message': message,
      };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) =>
      ActivityLogEntry(
        at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
        source: json['source']?.toString() ?? 'app',
        message: json['message']?.toString() ?? '',
      );
}

/// Device-only log of what the app did and when. No network, no upload.
class ActivityLogStore extends ChangeNotifier {
  List<ActivityLogEntry> _entries = <ActivityLogEntry>[];
  SharedPreferences? _prefs;

  List<ActivityLogEntry> get entries => List<ActivityLogEntry>.unmodifiable(_entries);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(activityLogPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries = decoded
              .whereType<Map>()
              .map((item) => ActivityLogEntry.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      } catch (_) {
        _entries = <ActivityLogEntry>[];
      }
    }
    notifyListeners();
  }

  Future<void> add(String source, String message) async {
    _prefs ??= await SharedPreferences.getInstance();
    final entry = ActivityLogEntry(
      at: DateTime.now().toUtc(),
      source: source.trim().isEmpty ? 'app' : source.trim(),
      message: message.trim(),
    );
    if (entry.message.isEmpty) return;
    _entries = <ActivityLogEntry>[entry, ..._entries];
    if (_entries.length > maxActivityEntries) {
      _entries = _entries.sublist(0, maxActivityEntries);
    }
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _prefs ??= await SharedPreferences.getInstance();
    _entries = <ActivityLogEntry>[];
    await _prefs!.remove(activityLogPrefsKey);
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(
      activityLogPrefsKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }
}

/// Single instance shared by services, background callbacks and the UI.
final ActivityLogStore activityLog = ActivityLogStore();
