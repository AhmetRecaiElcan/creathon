import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/event_repository.dart';
import '../../domain/agenda_entry.dart';
import '../../domain/event_session.dart';
import '../../domain/meeting_slot.dart';
import '../meetings/meetings_controller.dart';
import '../profile/profile_controller.dart';

/// The sessions the user actually added from the home feed, in time order.
///
/// Derived from the saved ids rather than stored as objects, so a session the
/// organiser edits or withdraws in Firestore is reflected here immediately.
final savedSessionsProvider = Provider<List<EventSession>>((ref) {
  final saved = ref.watch(profileProvider).savedEventIds;
  if (saved.isEmpty) return const [];

  final sessions = ref
      .watch(sessionsProvider)
      .where((session) => saved.contains(session.id))
      .toList();
  sessions.sort((a, b) => a.start.compareTo(b.start));
  return sessions;
});

/// Saved sessions and meetings merged into one chronological day.
///
/// Lives in its own library rather than beside either source, so neither the
/// programme providers nor the meeting controller has to know about the other.
final agendaTimelineProvider = Provider<List<AgendaEntry>>((ref) {
  final entries = <AgendaEntry>[
    ...ref.watch(savedSessionsProvider).map(SessionEntry.new),
    ...ref.watch(openMeetingsProvider).map(MeetingEntry.new),
  ];
  entries.sort((a, b) => a.start.compareTo(b.start));
  return entries;
});

/// Selectable meeting times, already checked against the user's own agenda and
/// their existing meetings.
final meetingSlotsProvider = Provider<List<MeetingSlot>>((ref) {
  return MeetingSlots.forDay(
    agenda: ref.watch(savedSessionsProvider),
    meetings: ref.watch(meetingsProvider),
  );
});
