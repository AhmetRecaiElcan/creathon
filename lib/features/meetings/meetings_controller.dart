import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meeting_repository.dart';
import '../../data/organization_repository.dart';
import '../../domain/meeting.dart';
import '../../domain/availability_slot.dart';
import '../../domain/organization.dart';
import '../../domain/user_role.dart';
import '../profile/profile_controller.dart';

/// The signed-in account's meetings.
///
/// Which side of the table they are on depends on the role: a visitor sees the
/// requests they sent, an exhibitor sees the requests addressed to them. Both
/// are the same collection read from a different angle.
final meetingsStreamProvider = StreamProvider<List<Meeting>>((ref) {
  final profile = ref.watch(profileProvider);
  final uid = profile.uid;
  if (uid == null) return Stream.value(const <Meeting>[]);

  final repository = ref.watch(meetingRepositoryProvider);
  return profile.role == UserRole.corporate
      ? repository.watchForOrganization(uid)
      : repository.watchForRequester(uid);
});

final meetingsProvider = Provider<List<Meeting>>(
  (ref) => ref.watch(meetingsStreamProvider).value ?? const [],
);

/// The meeting already arranged with a given exhibitor, if any. Lets the info
/// card swap "request a meeting" for its booked state.
final meetingWithProvider = Provider.family<Meeting?, String>((ref, orgId) {
  for (final meeting in ref.watch(meetingsProvider)) {
    if (meeting.organizationId == orgId) return meeting;
  }
  return null;
});

/// Sends and answers meeting requests.
class MeetingsController {
  const MeetingsController(this._ref);

  final Ref _ref;

  /// Asks [organization] for [start]. Throws [SlotTakenFailure] when another
  /// visitor claimed the slot first, or [MeetingFailure] otherwise.
  Future<Meeting> request({
    required Organization organization,
    required DateTime start,
    required DateTime end,
    MeetingMode mode = MeetingMode.inPerson,
    String? note,
  }) async {
    final profile = _ref.read(profileProvider);
    final uid = profile.uid;
    if (uid == null) {
      throw const MeetingFailure('Önce hesabını oluşturman gerekiyor.');
    }

    final trimmed = note?.trim();
    final meeting = Meeting(
      id: Meeting.idFor(organizationId: organization.id, start: start),
      organizationId: organization.id,
      organizationName: organization.name,
      requesterId: uid,
      requesterName: profile.fullName.isEmpty ? 'Ziyaretçi' : profile.fullName,
      requesterEmail: profile.email,
      start: start,
      end: end,
      // An online slot has no place to walk to; an in-person one meets at the
      // exhibitor's booth, or the shared area when they have none.
      location: switch (mode) {
        MeetingMode.online => 'Online görüşme',
        MeetingMode.inPerson => organization.standCode == null
            ? 'Networking Alanı'
            : 'Stand ${organization.standCode}',
      },
      status: MeetingStatus.requested,
      mode: mode,
      note: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );

    await _ref.read(meetingRepositoryProvider).request(meeting);
    return meeting;
  }

  Future<void> respond(Meeting meeting, MeetingStatus status) =>
      _ref.read(meetingRepositoryProvider).respond(meeting, status);
}

final meetingsControllerProvider = Provider<MeetingsController>(
  MeetingsController.new,
);

/// Slots a visitor may actually ask this exhibitor for.
///
/// Three things have to line up: the exhibitor declared the slot open, nobody
/// else has taken it, and it does not collide with the visitor's own day. The
/// blocked ones stay in the list so the reason is visible rather than the slot
/// silently missing.
final organizationSlotsProvider =
    Provider.family<List<OrganizationSlot>, String>((ref, orgId) {
      final organization = ref.watch(organizationByIdProvider(orgId));
      if (organization == null) return const [];

      final ownMeetings = ref.watch(meetingsProvider);
      final now = DateTime.now();

      final slots = <OrganizationSlot>[];
      for (final offer in organization.availability) {
        final start = offer.parseOn(now);
        if (start == null) continue;
        final end = start.add(const Duration(minutes: 30));

        Meeting? own;
        for (final meeting in ownMeetings) {
          if (meeting.start.isBefore(end) && start.isBefore(meeting.end)) {
            own = meeting;
            break;
          }
        }

        slots.add(
          OrganizationSlot(
            offer: offer,
            start: start,
            end: end,
            clash: own,
            isWithThisOrganization: own?.organizationId == orgId,
          ),
        );
      }
      return slots;
    });

/// One offered slot, with whatever is standing in its way.
class OrganizationSlot {
  const OrganizationSlot({
    required this.offer,
    required this.start,
    required this.end,
    required this.clash,
    required this.isWithThisOrganization,
  });

  /// What the exhibitor published for this time: the kind of meeting and what
  /// they mean it for.
  final AvailabilitySlot offer;

  final DateTime start;
  final DateTime end;

  String get label => offer.time;
  MeetingMode get mode => offer.mode;
  String? get note => offer.note;

  /// The visitor's own meeting occupying this time, if any.
  final Meeting? clash;

  /// Whether that clash is a meeting with this same exhibitor — which reads as
  /// "already booked" rather than as "you are busy".
  final bool isWithThisOrganization;

  bool get available => clash == null;

  String? get blockedReason {
    if (clash == null) return null;
    return isWithThisOrganization
        ? 'Bu saat için talebin gönderildi'
        : '${clash!.organizationName} ile toplantın var';
  }
}

/// Whole-day grid an exhibitor picks its availability from.
abstract final class SlotGrid {
  static const startHour = 9;
  static const endHour = 18;

  static List<String> get labels => [
    for (var hour = startHour; hour < endHour; hour++)
      for (final minute in ['00', '30'])
        '${hour.toString().padLeft(2, '0')}:$minute',
  ];
}
