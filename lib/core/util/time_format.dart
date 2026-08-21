/// 24-hour `HH:mm`. Shared so sessions, meetings and slots never disagree on
/// how a time is written.
String formatHm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
