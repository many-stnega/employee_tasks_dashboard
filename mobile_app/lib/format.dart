import 'package:intl/intl.dart';

import 'models.dart';

/// Myanmar time, the timezone used by the whole dashboard.
const Duration mmtOffset = Duration(hours: 6, minutes: 30);

const Map<String, String> engineerNames = <String, String>{
  'di_qing_bai': 'PhyuPyarChanMyaeKyaw',
  'doloresax': 'Aung Khant Moe',
  'zyme3': 'Htet Wai Yan',
  'hmue_gyi': 'Hmue Sat San',
  'kyawswarhtunlinnaung': 'Kyaw Swar Htun',
  'mkaddison': 'Yu Yu Aung',
};

DateTime _inMmt(DateTime? value) =>
    (value ?? DateTime.now()).toUtc().add(mmtOffset);

DateTime _dateFromKey(String key) =>
    DateTime.tryParse('${key}T12:00:00+06:30') ?? DateTime.now();

String prettyDate(String key) =>
    DateFormat.yMMMMEEEEd('en_US').format(_dateFromKey(key));

String timeHm(DateTime? value) => DateFormat.jm('en_US').format(_inMmt(value));

String dateTimeLabel(DateTime? value) =>
    DateFormat('MMM d, h:mm a', 'en_US').format(_inMmt(value));

String engineerLabel(String? username, {String? fallbackName}) {
  final handle = (username ?? '').replaceFirst(RegExp(r'^@'), '');
  final name = engineerNames[handle.toLowerCase()] ?? fallbackName;
  if (handle.isEmpty) return name ?? '';
  return name == null || name.isEmpty ? '@$handle' : '@$handle - $name';
}

String reportAuthorLabel(ReportEntry report) {
  final label = engineerLabel(report.authorUsername, fallbackName: report.authorName);
  if (label.isNotEmpty) return label;
  if (report.authorId != null) return 'Telegram ID ${report.authorId}';
  return 'Unknown (not recorded)';
}

/// Name shown in the UI. Telegram handles stay hidden until the user taps.
String engineerDisplayName(String? username, {String? fallbackName}) {
  final handle = (username ?? '').replaceFirst(RegExp(r'^@'), '');
  final name = engineerNames[handle.toLowerCase()] ?? fallbackName;
  if (name != null && name.isNotEmpty) return name;
  return 'Engineer';
}

String reportAuthorDisplayName(ReportEntry report) {
  final name = engineerNames[(report.authorUsername ?? '')
          .replaceFirst(RegExp(r'^@'), '')
          .toLowerCase()] ??
      report.authorName;
  if (name != null && name.isNotEmpty) return name;
  if (report.authorId != null) return 'Telegram ID ${report.authorId}';
  return 'Unknown (not recorded)';
}
