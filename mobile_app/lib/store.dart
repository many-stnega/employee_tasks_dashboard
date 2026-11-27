import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';

const String logsPrefsKey = 'daily_logs_v1';
const String _selectedDateKey = 'selected_date_v1';
const String _darkThemeKey = 'dark_theme_v1';
const String _serverUrlKey = 'server_url_v1';
const String _mobileTokenKey = 'mobile_token_v1';
const String _noticeKey = 'last_notice_v1';

// Legacy keys from the removed report-sending feature; purged on load so an
// old bot token does not keep sitting on the device.
const String _legacyTelegramUserIdKey = 'telegram_user_id_v1';
const String _legacyReportChatIdKey = 'report_chat_id_v1';
const String _legacyReporterNameKey = 'reporter_name_v1';
const String _legacyBotTokenKey = 'bot_token_v1';

String todayKey() {
  final now = DateTime.now().toUtc().add(mmtOffset);
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

Map<String, DailyLog> readStoredLogs(SharedPreferences prefs) {
  final raw = prefs.getString(logsPrefsKey);
  if (raw == null || raw.isEmpty) return <String, DailyLog>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, DailyLog>{};
    return decoded.map<String, DailyLog>((key, value) => MapEntry(
          key.toString(),
          DailyLog.fromJson(Map<String, dynamic>.from(value as Map)),
        ));
  } catch (_) {
    return <String, DailyLog>{};
  }
}

class TaskStore extends ChangeNotifier {
  SharedPreferences? _prefs;
  Map<String, DailyLog> _logs = <String, DailyLog>{};
  String _selectedDate = todayKey();
  bool _dark = false;
  String _serverUrl = '';
  String _mobileToken = '';
  String _notice = '';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    for (final key in <String>[
      _legacyTelegramUserIdKey,
      _legacyReportChatIdKey,
      _legacyReporterNameKey,
      _legacyBotTokenKey,
    ]) {
      await _prefs!.remove(key);
    }
    _logs = readStoredLogs(_prefs!);
    _selectedDate = _prefs!.getString(_selectedDateKey) ?? todayKey();
    _dark = _prefs!.getBool(_darkThemeKey) ?? false;
    _serverUrl = _prefs!.getString(_serverUrlKey) ?? '';
    _mobileToken = _prefs!.getString(_mobileTokenKey) ?? '';
    _notice = _prefs!.getString(_noticeKey) ?? '';
    notifyListeners();
  }

  DailyLog get current => _logs[_selectedDate] ?? DailyLog.empty(_selectedDate);
  List<String> get dates => _logs.keys.toList()..sort();
  String get selectedDate => _selectedDate;
  bool get dark => _dark;
  String get serverUrl => _serverUrl;
  String get mobileToken => _mobileToken;
  String get notice => _notice;
  bool isCached(String date) => _logs.containsKey(date);
  DailyLog? cachedDay(String date) => _logs[date];

  Future<void> _saveLogs() async {
    await _prefs?.setString(
      logsPrefsKey,
      jsonEncode(_logs.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  /// Stores a daily snapshot fetched from the server in the phone cache.
  Future<void> cacheDay(DailyLog day) async {
    final existing = _logs[day.date] ?? DailyLog.empty(day.date);
    _logs[day.date] = existing.replaceWith(day);
    await _saveLogs();
    notifyListeners();
  }

  Future<void> setSelectedDate(String value) async {
    if (value == _selectedDate) return;
    _selectedDate = value;
    await _prefs?.setString(_selectedDateKey, value);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    _dark = value;
    await _prefs?.setBool(_darkThemeKey, value);
    notifyListeners();
  }

  Future<void> setServerUrl(String value) async {
    _serverUrl = value.trim().replaceFirst(RegExp(r'/+$'), '');
    await _prefs?.setString(_serverUrlKey, _serverUrl);
    notifyListeners();
  }

  Future<void> setMobileToken(String value) async {
    _mobileToken = value.trim();
    await _prefs?.setString(_mobileTokenKey, _mobileToken);
    notifyListeners();
  }

  Future<void> setNotice(String value) async {
    _notice = value;
    await _prefs?.setString(_noticeKey, value);
    notifyListeners();
  }
}
