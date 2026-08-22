import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meeting_repository.dart';
import '../../data/organization_repository.dart';
import '../../domain/meeting.dart';
import '../../domain/availability_slot.dart';
import '../../domain/meeting_room.dart';
import '../../domain/organization.dart';
import '../profile/profile_controller.dart';

/// Requests addressed to this account — the ones it answers.
///
/// Only the exhibitor keeps hours, so only the exhibitor receives any; see
/// [UserRole.receivesMeetings]. Kept as its own provider rather than folded
/// into one role switch because the two directions are two sections on screen,
/// with different controls: one is answered, the other is waited on.
final hostedMeetingsStreamProvider = StreamProvider<List<Meeting>>((ref) {
  final profile = ref.watch(profileProvider);
  final uid = profile.uid;
  if (uid == null || !(profile.role?.receivesMeetings ?? false)) {
    return Stream.value(const <Meeting>[]);
  }
  return ref.watch(meetingRepositoryProvider).watchForOrganization(uid);
});

/// Requests this account sent — the ones it is waiting on.
///
/// Not gated by [UserRole.canRequestMeetings]: only two roles are offered the
/// request action, but any account that somehow holds a meeting has to be able
/// to see it. A role that never asked for one simply reads back nothing.
final sentMeetingsStreamProvider = StreamProvider<List<Meeting>>((ref) {
  final uid = ref.watch(profileProvider).uid;
  if (uid == null) return Stream.value(const <Meeting>[]);
  return ref.watch(meetingRepositoryProvider).watchForRequester(uid);
});

final hostedMeetingsProvider = Provider<List<Meeting>>(
  (ref) => ref.watch(hostedMeetingsStreamProvider).value ?? const [],
);

final sentMeetingsProvider = Provider<List<Meeting>>(
  (ref) => ref.watch(sentMeetingsStreamProvider).value ?? const [],
);

/// Every meeting this account is a party to, in time order.
///
/// What the agenda, the profile counter and the account teardown all read: none
/// of them cares which side of the table a meeting sits on, only that it is on
/// this person's day.
final meetingsProvider = Provider<List<Meeting>>((ref) {
  final all = [
    ...ref.watch(hostedMeetingsProvider),
    ...ref.watch(sentMeetingsProvider),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return all;
});

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
      // Only an investor has these, and they are the reason the exhibitor
      // reads the request at all — so they are stamped on it here rather than
      // looked up from a profile the exhibitor is not allowed to read.
      requesterCompany: profile.companyName.trim().isEmpty
          ? null
          : profile.companyName.trim(),
      requesterKind: profile.investorKind,
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

  /// Answers a request. Accepting an online one also mints the room it will be
  /// held in — acceptance is the first moment there is a meeting to hold, and
  /// the first moment a live link is not a link to something unagreed.
  ///
  /// A room already on the record is kept: re-confirming must not move the
  /// meeting somewhere the other side is not looking.
  Future<void> respond(Meeting meeting, MeetingStatus status) {
    final needsRoom =
        status == MeetingStatus.confirmed &&
        meeting.mode == MeetingMode.online &&
        meeting.roomName == null;

    return _ref.read(meetingRepositoryProvider).respond(
      meeting,
      status,
      roomName: needsRoom ? MeetingRoom.newName() : null,
    );
  }
}

final meetingsControllerProvider = Provider<MeetingsController>(
  MeetingsController.new,
);

/// Slots a visitor may actually ask this card for.
///
/// Three things have to line up: the card is open at that hour, nobody else has
/// taken it, and it does not collide with the visitor's own day. The blocked
/// ones stay in the list so the reason is visible rather than the slot silently
/// missing.
///
/// Reads [Organization.bookableAvailability] rather than the raw list, so a
/// founder who was never offered an availability grid still shows a day that
/// can be booked.
final organizationSlotsProvider =
    Provider.family<List<OrganizationSlot>, String>((ref, orgId) {
      final organization = ref.watch(organizationByIdProvider(orgId));
      if (organization == null) return const [];

      final ownMeetings = ref.watch(meetingsProvider);
      final ownUid = ref.watch(profileProvider).uid;
      final now = DateTime.now();

      final slots = <OrganizationSlot>[];
      for (final offer in organization.bookableAvailability) {
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
            // A founder who has been booked by an investor is busy at that
            // hour too, but the meeting is theirs to host — so it has to read
            // as "you are hosting X" rather than as their own venture's name.
            clashIsHosted: own != null && own.organizationId == ownUid,
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
    this.clashIsHosted = false,
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

  /// Whether the clash is a meeting this account is hosting rather than one it
  /// asked for — the founder's case, where the other party is the requester.
  final bool clashIsHosted;

  bool get available => clash == null;

  String? get blockedReason {
    final clash = this.clash;
    if (clash == null) return null;
    if (isWithThisOrganization) return 'Bu saat için talebin gönderildi';
    return clashIsHosted
        ? '${clash.requesterName} ile görüşmen var'
        : '${clash.organizationName} ile toplantın var';
  }
}
