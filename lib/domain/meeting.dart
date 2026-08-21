import 'package:flutter/material.dart';

import '../core/util/time_format.dart';
import 'availability_slot.dart';

enum MeetingStatus {
  requested('Talep gönderildi', Icons.schedule_send_rounded),
  confirmed('Onaylandı', Icons.check_circle_rounded),
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
    this.note,
  });

  final String id;

  final String organizationId;
  final String organizationName;

  final String requesterId;
  final String requesterName;
  final String? requesterEmail;

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

  String get startLabel => formatHm(start);
  String get endLabel => formatHm(end);
  String get timeLabel => '$startLabel – $endLabel';

  /// One request per exhibitor per slot. Expressing that as the document id
  /// makes the slot itself the thing that can only be claimed once, which is
  /// the only way Firestore can enforce it.
  static String idFor({
    required String organizationId,
    required DateTime start,
  }) => '${organizationId}__${start.toIso8601String()}';

  Meeting copyWith({MeetingStatus? status, String? note}) => Meeting(
    id: id,
    organizationId: organizationId,
    organizationName: organizationName,
    requesterId: requesterId,
    requesterName: requesterName,
    requesterEmail: requesterEmail,
    start: start,
    end: end,
    location: location,
    status: status ?? this.status,
    mode: mode,
    note: note ?? this.note,
  );

  Map<String, Object?> toMap() => {
    'organizationId': organizationId,
    'organizationName': organizationName,
    'requesterId': requesterId,
    'requesterName': requesterName,
    'requesterEmail': requesterEmail,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'location': location,
    'status': status.name,
    'mode': mode.id,
    'note': note,
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
      start: start,
      end: end,
      location: (map['location'] as String?) ?? 'Fuar alanı',
      status: MeetingStatus.fromId(map['status'] as String?),
      mode: MeetingMode.fromId(map['mode'] as String?),
      note: map['note'] as String?,
    );
  }
}
