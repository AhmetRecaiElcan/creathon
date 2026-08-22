import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nudges everything watching [clockProvider] on a slow beat.
///
/// Private because the tick itself means nothing — it exists only to invalidate
/// the clock, and anything reading the number instead of the time would be
/// reading an implementation detail.
final _tickProvider = StreamProvider<int>(
  (ref) => Stream.periodic(const Duration(seconds: 30), (count) => count),
);

/// The wall clock.
///
/// Anything that changes because *time passed* rather than because someone
/// tapped something reads this. An availability grid has to close 14:00 at two
/// o'clock, and a meeting has to become rateable the moment it ends — neither
/// would otherwise rebuild at that instant, and the screen would go on offering
/// an hour that is gone until the user happened to navigate away and back.
///
/// A plain [Provider] rather than a stream, deliberately. It always has a value
/// the moment it is read, which a `StreamProvider` does not: one read on a
/// provider nobody was watching yet would come back empty and fall through to
/// whatever default the caller picked — silently reading the real clock in a
/// test that had pinned it, which is exactly the bug this shape prevents.
///
/// Thirty seconds is close enough that the clock striking and the screen
/// changing feel like one event, and slow enough that the cost is nothing.
final clockProvider = Provider<DateTime>((ref) {
  ref.watch(_tickProvider);
  return DateTime.now();
});

/// The current time for a widget. Watches, so the widget rebuilds on the tick.
DateTime nowOf(WidgetRef ref) => ref.watch(clockProvider);
