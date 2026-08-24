import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/event_session.dart';
import 'package:creathon/domain/meeting.dart';
import 'package:creathon/domain/meeting_slot.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 8, 20);

DateTime _at(int hour, int minute) =>
    DateTime(_day.year, _day.month, _day.day, hour, minute);

EventSession _session({
  required DateTime start,
  required DateTime end,
  SessionKind kind = SessionKind.panel,
}) => EventSession(
  id: 'session',
  title: 'Savunma Teknolojilerinde Otonomi',
  speaker: 'Deniz Karaca',
  org: 'Nexora Robotik',
  kind: kind,
  venue: 'Ana Sahne',
  start: start,
  end: end,
  sectors: const ['Savunma Teknolojileri'],
);

Meeting _meeting({required DateTime start, required DateTime end}) => Meeting(
  id: 'm1',
  organizationId: 'org-1',
  organizationName: 'Nexora Robotik',
  requesterId: 'uid-1',
  requesterName: 'Elif Tunca',
  start: start,
  end: end,
  location: 'Stand A1',
  status: MeetingStatus.requested,
);

MeetingSlot _slotAt(List<MeetingSlot> slots, int hour, int minute) =>
    slots.firstWhere((s) => s.start == _at(hour, minute));

void main() {
  group('MeetingSlots.forDay', () {
    test('covers the whole window in half-hour steps', () {
      final slots = MeetingSlots.forDay(
        agenda: const [],
        meetings: const [],
        day: _day,
      );

      // Derived from SlotGrid, not written out: the event day has been widened
      // once already and is meant to be narrowed again, and a test that
      // hard-codes the hours turns each of those into a failure to chase
      // rather than a one-line edit.
      final hours = SlotGrid.endHour - SlotGrid.startHour;
      expect(slots, hasLength(hours * 2));
      expect(slots.first.start, _at(SlotGrid.startHour, 0));
      expect(slots.last.end, _at(SlotGrid.endHour, 0));
      expect(slots.every((s) => s.available), isTrue);
    });

    test('blocks slots that overlap an agenda session', () {
      final slots = MeetingSlots.forDay(
        agenda: [_session(start: _at(10, 30), end: _at(11, 30))],
        meetings: const [],
        day: _day,
      );

      expect(_slotAt(slots, 10, 30).available, isFalse);
      expect(_slotAt(slots, 11, 0).available, isFalse);
      expect(_slotAt(slots, 10, 30).blockedReason, contains('Panel'));
    });

    test('a slot that merely touches a session is still free', () {
      final slots = MeetingSlots.forDay(
        agenda: [_session(start: _at(10, 30), end: _at(11, 30))],
        meetings: const [],
        day: _day,
      );

      // Ends exactly when the session starts.
      expect(_slotAt(slots, 10, 0).available, isTrue);
      // Starts exactly when the session ends.
      expect(_slotAt(slots, 11, 30).available, isTrue);
    });

    test('blocks slots taken by an existing meeting and names it', () {
      final slots = MeetingSlots.forDay(
        agenda: const [],
        meetings: [_meeting(start: _at(14, 0), end: _at(14, 30))],
        day: _day,
      );

      final taken = _slotAt(slots, 14, 0);
      expect(taken.available, isFalse);
      expect(taken.blockedReason, contains('Nexora Robotik'));
      expect(_slotAt(slots, 14, 30).available, isTrue);
    });

    test('a meeting clash takes precedence over a session clash', () {
      final slots = MeetingSlots.forDay(
        agenda: [_session(start: _at(14, 0), end: _at(15, 0))],
        meetings: [_meeting(start: _at(14, 0), end: _at(14, 30))],
        day: _day,
      );

      // Both clash, but the user's own commitment is the more useful reason.
      expect(_slotAt(slots, 14, 0).blockedReason, contains('Nexora Robotik'));
    });

    test('a session spanning the whole window leaves nothing free', () {
      final slots = MeetingSlots.forDay(
        // "The whole window" has to mean the current window, not the one this
        // test was written against.
        agenda: [
          _session(
            start: _at(SlotGrid.startHour, 0),
            end: _at(SlotGrid.endHour, 0),
          ),
        ],
        meetings: const [],
        day: _day,
      );

      expect(slots.where((s) => s.available), isEmpty);
    });
  });
}
