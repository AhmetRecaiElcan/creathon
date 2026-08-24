import 'package:flutter/material.dart';

import '../core/util/time_format.dart';
import 'availability_slot.dart';
import 'investor_kind.dart';

enum MeetingStatus {
  requested('Talep gönderildi', Icons.schedule_send_rounded),
  confirmed('Onaylandı', Icons.check_circle_rounded),

  /// Ended by one of the two people who were in it, by pressing the button.
  ///
  /// Deliberately not something the clock can produce. A meeting is over when
  /// the people in it say it is over, not when the half-hour they booked runs
  /// out — a call that overruns is the normal case, not an error, and a card
  /// that swapped the join link for a rating form mid-conversation would end
  /// the meeting on their behalf.
  completed('Tamamlandı', Icons.task_alt_rounded),

  declined('Reddedildi', Icons.cancel_rounded);

  const MeetingStatus(this.label, this.icon);

  final String label;
  final IconData icon;

  static MeetingStatus fromId(String? id) {
    for (final status in values) {
      if (status.name == id) return status;
    }
    return MeetingStatus.requested;
  }
}

/// A meeting a visitor asked an exhibitor for, in one of the slots that
/// exhibitor declared itself free.
///
/// Both sides' names are copied onto the record rather than looked up: the
/// agenda has to render a meeting without waiting on a second read, and a
/// meeting must stay readable even if the other party edits their profile
/// afterwards.
@immutable
class Meeting {
  const Meeting({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.requesterId,
    required this.requesterName,
    required this.start,
    required this.end,
    required this.location,
    required this.status,
    this.mode = MeetingMode.inPerson,
    this.requesterEmail,
    this.requesterCompany,
    this.requesterKind,
    this.note,
    this.roomName,
  });

  final String id;

  final String organizationId;
  final String organizationName;

  final String requesterId;
  final String requesterName;
  final String? requesterEmail;

  /// The fund or company the requester came on behalf of, and what kind of
  /// investor they are.
  ///
  /// Copied onto the record like the names are, because this is what the
  /// exhibitor decides on: "Ada Ventures · Melek yatırımcı" answers whether the
  /// slot is worth giving up, where a bare name does not. Null for a requester
  /// who represents nobody but themselves.
  final String? requesterCompany;
  final InvestorKind? requesterKind;

  final DateTime start;
  final DateTime end;

  /// Where to meet — the exhibitor's booth when it has one.
  final String location;

  final MeetingStatus status;

  /// Whether this happens at the booth or on a call. Copied from the slot the
  /// exhibitor opened, so the record still says how to meet even if the
  /// exhibitor later closes or changes that slot.
  final MeetingMode mode;

  /// Optional message sent with the request.
  final String? note;

  /// The video room this meeting happens in, for an online one that has been
  /// confirmed.
  ///
  /// Written by the host at the moment they accept, and never before: a room
  /// minted when the request was *sent* would be a live, joinable link to a
  /// meeting the other side had not yet agreed to. Null on an in-person
  /// meeting, and on an online one still waiting for an answer.
  final String? roomName;

  /// Whether there is a call to walk into right now.
  ///
  /// All three conditions matter: in person there is nothing to click, before
  /// the host accepts there is no agreement, and without a room there is no
  /// link — a button that appeared in any of those cases would lie.
  ///
  /// The link itself is not here: it has to be signed with the video tenant's
  /// private key, which is why a function issues it. This only says whether
  /// there is any point in asking for one.
  bool get isJoinable =>
      mode == MeetingMode.online &&
      status == MeetingStatus.confirmed &&
      roomName != null;

  /// Whether the meeting's booked half-hour is behind us.
  ///
  /// Takes the time rather than reading the clock so a caller that already
  /// watches a ticking clock gets an answer consistent with the rest of the
  /// frame — two widgets disagreeing about whether a meeting is over, because
  /// they each looked at the clock a millisecond apart, is a real bug.
  ///
  /// Says nothing about whether the meeting is *finished*: see [isOver].
  bool hasEndedBy(DateTime now) => now.isAfter(end);

  /// Whether the meeting can be ended now.
  ///
  /// From its start time on, and only while it is agreed. Before it starts
  /// there is nothing to end — backing out of a meeting that has not happened
  /// is cancelling, which is a different act with a different button.
  bool canFinishAt(DateTime now) =>
      status == MeetingStatus.confirmed && !now.isBefore(start);

  /// Whether the two parties are done with this meeting.
  ///
  /// A stored fact, not a calculation over the clock. This used to be
  /// "confirmed and the half-hour has passed", which meant the join link
  /// vanished and a rating form appeared while the call was still going — a
  /// meeting that ran five minutes long looked, to both sides, like a meeting
  /// that had already been rated out from under them. Now it takes someone
  /// pressing *Görüşmeyi bitir*.
  bool get isOver => status == MeetingStatus.completed;

  /// A meeting that happened and is still owed a rating.
  ///
  /// Whether *this* account has already rated it is not knowable here — that
  /// lives in the feedback collection.
  bool get awaitsFeedback => isOver;

  /// How the requester is introduced to the host: the fund and the kind when
  /// there are any, and the address when there are not — an exhibitor should
  /// never be shown a nameless row.
  String get requesterDetail {
    final parts = [
      if (requesterCompany != null && requesterCompany!.trim().isNotEmpty)
        requesterCompany!.trim(),
      if (requesterKind != null) requesterKind!.shortLabel,
    ];
    if (parts.isEmpty) return requesterEmail ?? 'Ziyaretçi';
    return parts.join('  ·  ');
  }

  String get startLabel => formatHm(start);
  String get endLabel => formatHm(end);
  String get timeLabel => '$startLabel – $endLabel';

  /// `Bugün`, `Yarın`, or a date. The exhibitor answering a request has to know
  /// which day it is for before anything else about it matters.
  String get dayLabel => formatDay(start);

  /// `Bugün · 10:00 – 10:30 · Yüz yüze` — the whole appointment in one line,
  /// which is what both an approval screen and an agenda row need.
  String get whenLabel => '$dayLabel  ·  $timeLabel  ·  ${mode.label}';

  /// One request per exhibitor per slot. Expressing that as the document id
  /// makes the slot itself the thing that can only be claimed once, which is
  /// the only way Firestore can enforce it.
  static String idFor({
    required String organizationId,
    required DateTime start,
  }) => '${organizationId}__${start.toIso8601String()}';

  Meeting copyWith({
    MeetingStatus? status,
    String? note,
    String? roomName,
  }) => Meeting(
    id: id,
    organizationId: organizationId,
    organizationName: organizationName,
    requesterId: requesterId,
    requesterName: requesterName,
    requesterEmail: requesterEmail,
    requesterCompany: requesterCompany,
    requesterKind: requesterKind,
    start: start,
    end: end,
    location: location,
    status: status ?? this.status,
    mode: mode,
    note: note ?? this.note,
    roomName: roomName ?? this.roomName,
  );

  Map<String, Object?> toMap() => {
    'organizationId': organizationId,
    'organizationName': organizationName,
    'requesterId': requesterId,
    'requesterName': requesterName,
    'requesterEmail': requesterEmail,
    'requesterCompany': requesterCompany,
    'requesterKind': requesterKind?.id,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'location': location,
    'status': status.name,
    'mode': mode.id,
    'note': note,
    'roomName': roomName,
  };

  /// Returns null when the row cannot be read as a meeting, so one bad
  /// document does not blank out the whole agenda.
  static Meeting? fromMap(Map<String, Object?> map, {required String id}) {
    final start = DateTime.tryParse((map['start'] as String?) ?? '');
    final end = DateTime.tryParse((map['end'] as String?) ?? '');
    final organizationId = map['organizationId'] as String?;
    final requesterId = map['requesterId'] as String?;
    if (start == null ||
        end == null ||
        organizationId == null ||
        requesterId == null) {
      return null;
    }

    return Meeting(
      id: id,
      organizationId: organizationId,
      organizationName: (map['organizationName'] as String?) ?? 'Kurum',
      requesterId: requesterId,
      requesterName: (map['requesterName'] as String?) ?? 'Ziyaretçi',
      requesterEmail: map['requesterEmail'] as String?,
      requesterCompany: map['requesterCompany'] as String?,
      requesterKind: InvestorKind.fromId(map['requesterKind'] as String?),
      start: start,
      end: end,
      location: (map['location'] as String?) ?? 'Fuar alanı',
      status: MeetingStatus.fromId(map['status'] as String?),
      mode: MeetingMode.fromId(map['mode'] as String?),
      note: map['note'] as String?,
      roomName: map['roomName'] as String?,
    );
  }
}
