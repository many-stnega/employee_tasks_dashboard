import 'dart:convert';

import 'package:http/http.dart' as http;

import 'admin_models.dart';
import 'models.dart';

class DataServiceException implements Exception {
  final String message;
  const DataServiceException(this.message);

  @override
  String toString() => message;
}

/// Read-only client for the dashboard's /api/mobile endpoints.
///
/// The app calls this only when a day is needed (open, date change, refresh).
/// Whatever comes back is cached by [TaskStore] and rendered from that cache.
class DataService {
  final String baseUrl;
  final String token;
  final String adminToken;
  final http.Client _client;

  DataService({
    required this.baseUrl,
    required this.token,
    this.adminToken = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get isConfigured => baseUrl.isNotEmpty && token.isNotEmpty;

  Map<String, String> get _headers => <String, String>{
        'X-Mobile-Token': token,
        'Accept': 'application/json',
      };

  Map<String, String> get _adminHeaders => <String, String>{
        'X-Mobile-Admin-Token': adminToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri uriFor(String path) {
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix');
  }

  Future<List<String>> fetchDates() async {
    _checkConfig();
    final response = await _client
        .get(uriFor('/api/mobile/dates'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final decoded = _decode(response);
    final raw = decoded['dates'];
    if (raw is! List) throw const DataServiceException('Invalid dates response.');
    return raw.whereType<String>().toList();
  }

  Future<DailyLog> fetchDay(String date) async {
    _checkConfig();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const DataServiceException('Invalid date.');
    }
    final response = await _client
        .get(uriFor('/api/mobile/data/$date'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final decoded = _decode(response);
    final log = DailyLog.fromJson(decoded);
    if (log.date != date) {
      throw const DataServiceException('Server returned a different date.');
    }
    return log;
  }

  Future<MobileSettings> fetchSettings() async {
    _checkConfig();
    final response = await _client
        .get(uriFor('/api/mobile/settings'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return MobileSettings.fromJson(_decode(response));
  }

  Future<MobileSettings> saveSettings(MobileSettings settings) async {
    if (baseUrl.isEmpty || adminToken.isEmpty) {
      throw const DataServiceException(
        'Set the server URL and admin token in Settings first.',
      );
    }
    final response = await _client
        .put(
          uriFor('/api/mobile/settings'),
          headers: _adminHeaders,
          body: jsonEncode(settings.toJson()),
        )
        .timeout(const Duration(seconds: 20));
    return MobileSettings.fromJson(_decode(response));
  }

  void close() => _client.close();

  void _checkConfig() {
    if (!isConfigured) {
      throw const DataServiceException(
        'Set the server URL and mobile API token in Settings first.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 401) {
      throw const DataServiceException('Mobile API token was rejected.');
    }
    if (response.statusCode == 404) {
      throw const DataServiceException('No record for this date on the server.');
    }
    if (response.statusCode == 400) {
      String detail = 'Server rejected the settings.';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['description'] is String) {
          detail = decoded['description'] as String;
        }
      } catch (_) {}
      throw DataServiceException(detail);
    }
    if (response.statusCode != 200) {
      throw DataServiceException('Server returned HTTP ${response.statusCode}.');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const DataServiceException('Invalid JSON response.');
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const DataServiceException('Server returned invalid JSON.');
    }
  }
}
