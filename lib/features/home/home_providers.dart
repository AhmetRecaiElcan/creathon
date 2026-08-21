import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/event_repository.dart';
import '../../domain/event_session.dart';
import '../profile/profile_controller.dart';

/// The home feed: the whole published programme, with the sessions that touch
/// the user's interests lifted to the top.
///
/// Nothing is hidden. A visitor browsing the feed is choosing what to attend,
/// so filtering the programme down to their tags would remove exactly the
/// discoveries the event is for — the interests decide the order instead.
final feedProvider = Provider<List<EventSession>>((ref) {
  final sectors = ref.watch(profileProvider).sectors;
  final sessions = [...ref.watch(sessionsProvider)];

  sessions.sort((a, b) {
    final overlap = b.overlapWith(sectors).compareTo(a.overlapWith(sectors));
    if (overlap != 0) return overlap;
    return a.start.compareTo(b.start);
  });
  return sessions;
});

/// Just the part of the feed that matches an interest, for the "senin için"
/// rail. Empty when the programme has not been published yet.
final recommendedSessionsProvider = Provider<List<EventSession>>((ref) {
  final sectors = ref.watch(profileProvider).sectors;
  return ref
      .watch(feedProvider)
      .where((session) => session.overlapWith(sectors) > 0)
      .toList(growable: false);
});
