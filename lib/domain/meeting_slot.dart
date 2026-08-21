import 'package:flutter/foundation.dart';

import '../core/util/time_format.dart';
import 'event_session.dart';
import 'meeting.dart';

/// A candidate meeting time, already checked against everything else on the
/// user's day.
///
/// Unavailable slots are kept in the list rather than filtered out: showing
/// *why* a time is gone ("Panel ile çakışıyor") is what makes the agenda feel
/// aware of the user's day instead of arbitrary.
@immutable
class MeetingSlot {
  const MeetingSlot({
    required this.start,
    required this.end,
    this.clashingSession,
    this.clashingMeeting,
  });

  final DateTime start;
  final DateTime end;

  /// The agenda session occupying this slot, if any.
  final EventSession? clashingSession;

  /// An already-requested meeting occupying this slot, if any.
  final Meeting? clashingMeeting;

  bool get available => clashingSession == null && clashingMeeting == null;

  String get label => formatHm(start);

  /// Short human reason the slot is taken, or null when it is free.
  String? get blockedReason {
    if (clashingMeeting != null) {
      return '${clashingMeeting!.organizationName} ile toplantı';
    }
    if (clashingSession != null) {
      return '${clashingSession!.kind.label} ile çakışıyor';
    }
    return null;
  }
}

abstract final class MeetingSlots {
  static const _slotMinutes = 30;

  /// Builds the day's slots and marks the ones already taken.
  ///
  /// [agenda] and [meetings] are the user's own day, so the same slot can be
  /// free for one user and blocked for another.
  static List<MeetingSlot> forDay({
    required List<EventSession> agenda,
    required List<Meeting> meetings,
    int startHour = 9,
    int endHour = 18,
    DateTime? day,
  }) {
    final base = day ?? DateTime.now();
    final slots = <MeetingSlot>[];

    var cursor = DateTime(base.year, base.month, base.day, startHour);
    final dayEnd = DateTime(base.year, base.month, base.day, endHour);

    while (cursor.isBefore(dayEnd)) {
      final slotEnd = cursor.add(const Duration(minutes: _slotMinutes));

      EventSession? clashingSession;
      for (final session in agenda) {
        if (_overlaps(cursor, slotEnd, session.start, session.end)) {
          clashingSession = session;
          break;
        }
      }

      Meeting? clashingMeeting;
      for (final meeting in meetings) {
        if (_overlaps(cursor, slotEnd, meeting.start, meeting.end)) {
          clashingMeeting = meeting;
          break;
        }
      }

      slots.add(
        MeetingSlot(
          start: cursor,
          end: slotEnd,
          clashingSession: clashingSession,
          clashingMeeting: clashingMeeting,
        ),
      );
      cursor = slotEnd;
    }

    return slots;
  }

  /// Half-open interval overlap: two blocks that merely touch do not clash.
  static bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) => aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}
