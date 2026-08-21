import 'event_session.dart';
import 'meeting.dart';

/// One block on the user's day, whatever kind of thing it is.
///
/// The brief calls for an agenda where a requested meeting lands next to the
/// sessions it has to fit around, so both live in one sorted timeline rather
/// than in two lists the user has to reconcile.
sealed class AgendaEntry {
  const AgendaEntry();

  DateTime get start;
  DateTime get end;
}

final class SessionEntry extends AgendaEntry {
  const SessionEntry(this.session);

  final EventSession session;

  @override
  DateTime get start => session.start;

  @override
  DateTime get end => session.end;
}

final class MeetingEntry extends AgendaEntry {
  const MeetingEntry(this.meeting);

  final Meeting meeting;

  @override
  DateTime get start => meeting.start;

  @override
  DateTime get end => meeting.end;
}
