import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_log.dart';
import 'message_service.dart';

const String sentMessagesPrefsKey = 'sent_messages_v1';

class SentMessage {
  final int id;
  final String phone;
  final String body;
  final DateTime sentAt;

  const SentMessage({
    required this.id,
    required this.phone,
    required this.body,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'phone': phone,
        'body': body,
        'sent_at': sentAt.toIso8601String(),
      };

  factory SentMessage.fromJson(Map<String, dynamic> json) => SentMessage(
        id: (json['id'] as num).toInt(),
        phone: (json['phone'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        sentAt: DateTime.parse(json['sent_at'] as String),
      );
}

class MessageStore extends ChangeNotifier {
  MessageStore({required this.gateway});

  final SmsGateway gateway;
  SharedPreferences? _prefs;
  List<SentMessage> _messages = <SentMessage>[];

  List<SentMessage> get messages => List<SentMessage>.unmodifiable(_messages);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(sentMessagesPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _messages = decoded
            .whereType<Map>()
            .map((item) => SentMessage.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (_) {
        _messages = <SentMessage>[];
      }
    }
    notifyListeners();
  }

  Future<void> send(String phone, String body) async {
    final number = phone.trim();
    final text = body.trim();
    if (number.isEmpty || text.isEmpty) return;
    await gateway.send(phone: number, body: text);
    await activityLog.add('sms', 'SMS sent to $number.');
    final message = SentMessage(
      id: DateTime.now().microsecondsSinceEpoch % 1000000000,
      phone: number,
      body: text,
      sentAt: DateTime.now().toUtc(),
    );
    _messages = <SentMessage>[message, ..._messages];
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(
      sentMessagesPrefsKey,
      jsonEncode(_messages.map((item) => item.toJson()).toList()),
    );
  }
}
