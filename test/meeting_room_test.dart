import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/meeting.dart';
import 'package:creathon/domain/meeting_room.dart';
import 'package:creathon/domain/org_kind.dart';
import 'package:creathon/domain/organization.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two rules that keep an online meeting honest: a room nobody can guess
/// their way into, and a link that only exists once both sides have agreed.
void main() {
  Meeting meeting({
    MeetingMode mode = MeetingMode.online,
    MeetingStatus status = MeetingStatus.confirmed,
    String? roomName = 'takeoff-abcdefghijkmnp',
  }) {
    final start = DateTime(2026, 5, 20, 10);
    return Meeting(
      id: 'org-1__x',
      organizationId: 'org-1',
      organizationName: 'Nexora Robotik',
      requesterId: 'uid-1',
      requesterName: 'Elif Tunca',
      start: start,
      end: start.add(const Duration(minutes: 30)),
      location: 'Online görüşme',
      status: status,
      mode: mode,
      roomName: roomName,
    );
  }

  Organization card({
    OrgKind kind = OrgKind.startup,
    List<AvailabilitySlot> availability = const [],
  }) => Organization(
    id: 'org-1',
    kind: kind,
    name: 'Nexora Robotik',
    email: 'bilgi@nexora.com',
    description: 'Otonom seyir yazılımı.',
    brand: BrandColor.emerald,
    availability: availability,
  );

  test('room names do not repeat', () {
    final names = {for (var i = 0; i < 500; i++) MeetingRoom.newName()};
    expect(names, hasLength(500));
  });

  test('a room name carries no readable detail of the meeting', () {
    final name = MeetingRoom.newName();
    expect(name, startsWith('takeoff-'));
    // Anyone holding the URL can join, so a name that could be rebuilt from an
    // organisation id and a clock time would be an open door.
    expect(name.substring('takeoff-'.length), hasLength(14));
    expect(name, matches(RegExp(r'^takeoff-[a-z2-9]+$')));
    expect(name, isNot(contains('org-1')));
  });

  test('a link is worth asking for only once both sides have agreed', () {
    expect(meeting().isJoinable, isTrue);
    expect(meeting(mode: MeetingMode.inPerson).isJoinable, isFalse);
    expect(meeting(status: MeetingStatus.requested).isJoinable, isFalse);
    expect(meeting(roomName: null).isJoinable, isFalse);
  });

  test('a venture with no declared hours is open all day, online', () {
    final slots = card().bookableAvailability;
    // "All day" means whatever SlotGrid currently says the day is — see the
    // note on SlotGrid.endHour.
    expect(slots, hasLength(SlotGrid.labels.length));
    expect(slots.first.time, SlotGrid.labels.first);
    expect(slots.last.time, SlotGrid.labels.last);
    expect(slots.every((slot) => slot.mode == MeetingMode.online), isTrue);
  });

  test('a company that opened no hours stays closed', () {
    // It was handed the grid and ticked nothing, which is an answer — unlike a
    // venture, which is never asked.
    expect(card(kind: OrgKind.corporate).bookableAvailability, isEmpty);
  });

  test('declared hours always win over the fallback', () {
    final declared = [const AvailabilitySlot(time: '14:00')];
    expect(card(availability: declared).bookableAvailability, declared);
    expect(
      card(kind: OrgKind.corporate, availability: declared)
          .bookableAvailability,
      declared,
    );
  });
}
