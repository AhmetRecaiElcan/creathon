/// 24-hour `HH:mm`. Shared so sessions, meetings and slots never disagree on
/// how a time is written.
String formatHm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// Which day something falls on, from the reader's point of view.
///
/// "Bugün" and "Yarın" rather than a date whenever they apply: an exhibitor
/// answering a request needs to know if it is in an hour or next week, and a
/// date makes them do that arithmetic themselves. Written by hand instead of
/// through `intl` — one language, twelve words, and no 2 MB of locale data.
String formatDay(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final difference = DateTime(day.year, day.month, day.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;

  return switch (difference) {
    0 => 'Bugün',
    1 => 'Yarın',
    -1 => 'Dün',
    _ => '${day.day} ${_months[day.month - 1]}',
  };
}
