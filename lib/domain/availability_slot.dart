import 'package:flutter/material.dart';

/// How a meeting happens. The visitor needs to know before accepting a time:
/// walking to a booth and joining a call are different commitments.
enum MeetingMode {
  inPerson(
    id: 'inPerson',
    label: 'Yüz yüze',
    icon: Icons.storefront_rounded,
  ),
  online(id: 'online', label: 'Online', icon: Icons.videocam_rounded);

  const MeetingMode({
    required this.id,
    required this.label,
    required this.icon,
  });

  /// Stable key for Firestore; never localise this.
  final String id;

  final String label;
  final IconData icon;

  static MeetingMode fromId(String? id) {
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return MeetingMode.inPerson;
  }
}

/// One half-hour an exhibitor opened for meetings, with what they intend it for.
///
/// Richer than a bare time because the exhibitor is making an offer, not just
/// marking a calendar: "14:00, online, portföy görüşmesi" tells a visitor
/// whether the slot is for them before they spend it.
@immutable
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.time,
    this.mode = MeetingMode.inPerson,
    this.note,
  });

  /// `HH:mm` start on the event day. Doubles as the slot's identity — an
  /// exhibitor cannot be in two places at once, so one entry per time.
  final String time;

  final MeetingMode mode;

  /// What the exhibitor wants to use the slot for.
  final String? note;

  String get endTime {
    final start = parseOn(DateTime.now());
    if (start == null) return time;
    final end = start.add(const Duration(minutes: 30));
    return '${end.hour.toString().padLeft(2, '0')}:'
        '${end.minute.toString().padLeft(2, '0')}';
  }

  /// The slot as an instant on [day]. Null when [time] is malformed.
  DateTime? parseOn(DateTime day) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  AvailabilitySlot copyWith({MeetingMode? mode, String? note}) =>
      AvailabilitySlot(
        time: time,
        mode: mode ?? this.mode,
        note: note ?? this.note,
      );

  Map<String, Object?> toMap() => {
    'time': time,
    'mode': mode.id,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };

  static AvailabilitySlot? fromMap(Map<String, Object?> map) {
    final time = (map['time'] as String?)?.trim();
    if (time == null || time.isEmpty) return null;
    return AvailabilitySlot(
      time: time,
      mode: MeetingMode.fromId(map['mode'] as String?),
      note: (map['note'] as String?)?.trim(),
    );
  }
}

/// The event day, cut into the half-hours a meeting can start on.
///
/// One definition for both sides of the same grid: the exhibitor ticks slots
/// out of it, and a card with no ticks at all is read as the whole of it.
abstract final class SlotGrid {
  static const startHour = 0;

  /// Exclusive: the last slot starts half an hour before this, so 24 means the
  /// day runs to 00:00 and 18 means it stops at 18:00.
  ///
  /// **These two numbers are the only definition of the event day.** Nothing
  /// else — not `MeetingSlots.forDay`, not the tests — may hard-code an hour,
  /// so widening or narrowing the day stays a one-line edit. It was opened to
  /// midnight on 2026-08-24 at the organiser's request and is meant to be
  /// pulled back later; putting `18` back here is the whole revert.
  static const endHour = 24;

  static List<String> get labels => [
    for (var hour = startHour; hour < endHour; hour++)
      for (final minute in ['00', '30'])
        '${hour.toString().padLeft(2, '0')}:$minute',
  ];

  /// The whole day as open online slots.
  ///
  /// What a founder's card offers when they never declared hours. They are
  /// given no availability grid — they spend the fair walking the hall, not
  /// sitting at a counter — so an empty list from a venture means "reach me
  /// whenever", not "never". Online, because that is the one way to meet
  /// someone who has no booth to be found at.
  static List<AvailabilitySlot> get openAllDay => [
    for (final label in labels)
      AvailabilitySlot(time: label, mode: MeetingMode.online),
  ];
}
