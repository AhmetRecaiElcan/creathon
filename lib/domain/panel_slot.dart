/// The stage schedule an exhibitor can book a talk in.
///
/// Days are numbered rather than dated because the app has no calendar for the
/// event yet — the programme itself is anchored to "today" wherever it runs.
/// A number is honest about that and still sorts correctly; swapping in real
/// dates later only changes [labelFor].
abstract final class PanelSlots {
  /// How many days the fair runs.
  static const dayCount = 3;

  /// Talks run through the working day, on the hour.
  static const startHour = 9;
  static const endHour = 17;

  static List<int> get days => [for (var day = 1; day <= dayCount; day++) day];

  static List<String> get hours => [
    for (var hour = startHour; hour <= endHour; hour++)
      '${hour.toString().padLeft(2, '0')}:00',
  ];

  static String dayLabel(int day) => '$day. Gün';

  /// `2. Gün · 14:00`, or null when no talk was booked.
  static String? labelFor(int? day, String? time) {
    if (day == null || time == null || time.isEmpty) return null;
    return '${dayLabel(day)} · $time';
  }

  /// Sortable key so a list of talks reads as a schedule.
  static int orderOf(int? day, String? time) {
    if (day == null || time == null) return 1 << 20;
    final hour = int.tryParse(time.split(':').first) ?? 0;
    return day * 100 + hour;
  }
}
