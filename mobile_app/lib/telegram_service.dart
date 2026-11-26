import 'dart:convert';

import 'package:http/http.dart' as http;

/// Conservative split matching backend_python/bot.py (Telegram allows 4096).
const int telegramChunkLimit = 4000;

List<String> chunkText(String text, {int limit = telegramChunkLimit}) {
  if (text.isEmpty) return const <String>[];
  final chunks = <String>[];
  var remaining = text;
  while (remaining.length > limit) {
    var splitAt = remaining.lastIndexOf('\n', limit);
    if (splitAt <= 0) splitAt = limit;
    chunks.add(remaining.substring(0, splitAt));
    remaining = remaining.substring(splitAt).replaceFirst(RegExp(r'^\n+'), '');
  }
  if (remaining.isNotEmpty) chunks.add(remaining);
  return chunks;
}

class TelegramResult {
  final bool ok;
  final String? error;

  const TelegramResult.ok() : ok = true, error = null;
  const TelegramResult.fail(this.error) : ok = false;

  @override
  String toString() => ok ? 'ok' : 'failed: $error';
}

/// Sends a report message straight to Telegram. No backend call is made.
///
/// The token must be entered by the user in Settings: it is never bundled in
/// the app and must never be logged.
Future<TelegramResult> sendReport({
  required String token,
  required String chatId,
  required String text,
}) async {
  if (token.trim().isEmpty) {
    return const TelegramResult.fail('Bot token is not configured in Settings.');
  }
  if (chatId.trim().isEmpty) {
    return const TelegramResult.fail('Report chat ID is not configured in Settings.');
  }
  final chunks = chunkText(text);
  if (chunks.isEmpty) return const TelegramResult.fail('Report is empty.');

  final uri = Uri.parse('https://api.telegram.org/bot${token.trim()}/sendMessage');
  try {
    for (final chunk in chunks) {
      final response = await http.post(
        uri,
        body: <String, String>{'chat_id': chatId.trim(), 'text': chunk},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return TelegramResult.fail('HTTP ${response.statusCode}: ${_responseDetail(response.body)}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        return TelegramResult.fail(_responseDetail(response.body));
      }
    }
  } catch (error) {
    return TelegramResult.fail('Could not reach Telegram: $error');
  }
  return const TelegramResult.ok();
}

String _responseDetail(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final description = decoded['description'];
      if (description is String && description.isNotEmpty) return description;
    }
  } catch (_) {}
  return body.length > 200 ? '${body.substring(0, 200)}…' : body;
}
