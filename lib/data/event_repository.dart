import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/event_session.dart';

/// The event programme, read live from Firestore.
///
/// Expected shape of a document in `events`:
/// ```
/// { title, speaker, org, kind, venue, start: Timestamp, end: Timestamp,
///   sectors: [String] }
/// ```
/// The collection is empty until the organiser fills it, and an empty
/// programme is a legitimate state the screens render rather than an error.
abstract final class EventRepository {
  static const collection = 'events';

  static Stream<List<EventSession>> watch() {
    if (!firebaseReady) return Stream.value(const <EventSession>[]);
    return FirebaseFirestore.instance
        .collection(collection)
        .orderBy('start')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(fromDoc)
              .nonNulls
              .toList(growable: false),
        );
  }

  /// Returns null for a document that cannot be read as a session, so one bad
  /// row entered in the console does not blank out the whole programme.
  static EventSession? fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final start = _time(data['start']);
    final end = _time(data['end']);
    if (start == null || end == null) return null;

    return EventSession(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Adsız oturum',
      speaker: (data['speaker'] as String?) ?? '',
      org: (data['org'] as String?) ?? '',
      kind: _kind(data['kind'] as String?),
      venue: (data['venue'] as String?) ?? '',
      start: start,
      end: end,
      sectors: [...?(data['sectors'] as List?)?.whereType<String>()],
    );
  }

  static DateTime? _time(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    String text => DateTime.tryParse(text),
    _ => null,
  };

  static SessionKind _kind(String? id) {
    for (final kind in SessionKind.values) {
      if (kind.name == id) return kind;
    }
    return SessionKind.panel;
  }
}

/// Live programme. Empty list while loading or when the collection is empty —
/// the screens have a designed empty state either way.
final eventsStreamProvider = StreamProvider<List<EventSession>>(
  (ref) => EventRepository.watch(),
);

final sessionsProvider = Provider<List<EventSession>>(
  (ref) => ref.watch(eventsStreamProvider).value ?? const [],
);
