/// Calculates the next wall-clock occurrence in Myanmar time for a cron job.
DateTime nextOccurrence(
  DateTime base,
  String repeat,
  List<int> weekdays, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  if (repeat == 'daily') {
    var next = DateTime(
      reference.year,
      reference.month,
      reference.day,
      base.hour,
      base.minute,
    );
    if (!next.isAfter(reference)) next = next.add(const Duration(days: 1));
    return next;
  }
  if (repeat == 'weekly' && weekdays.isNotEmpty) {
    final days = <int>[...weekdays]..sort();
    for (final weekday in days) {
      var next = DateTime(
        reference.year,
        reference.month,
        reference.day,
        base.hour,
        base.minute,
      );
      next = next.add(Duration(days: (weekday - next.weekday) % 7));
      if (next.isAfter(reference)) return next;
    }
    var next = DateTime(
      reference.year,
      reference.month,
      reference.day,
      base.hour,
      base.minute,
    );
    return next.add(Duration(days: (days.first - next.weekday) % 7 + 7));
  }
  var next = DateTime(base.year, base.month, base.day, base.hour, base.minute);
  if (!next.isAfter(reference)) next = next.add(const Duration(days: 1));
  return next;
}
