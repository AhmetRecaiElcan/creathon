import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_repository.dart';
import '../domain/event_session.dart';

/// Raised when the panel refuses a session rather than when Firestore does, so
/// the form can say why in Turkish instead of surfacing a rules error.
class EventFailure implements Exception {
  const EventFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The programme, from the organiser's side.
///
/// Writes the same document shape `EventRepository.fromDoc` reads — that parser
/// is the contract, and going through the same [EventSession] model on both
/// sides is what stops the panel from publishing a row the phones would skip.
class EventAdminRepository {
  const EventAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _events =>
      _db.collection(EventRepository.collection);

  /// Adds a session to the programme.
  ///
  /// `start` and `end` are written as Timestamps because that is what the
  /// phones' parser prefers, and because an ISO string would sort by text.
  Future<void> add({
    required String title,
    required String venue,
    required DateTime start,
    required DateTime end,
    required SessionKind kind,
    String speaker = '',
    String org = '',
    List<String> sectors = const [],
  }) async {
    if (title.trim().isEmpty) throw const EventFailure('Etkinlik adı gir.');
    if (venue.trim().isEmpty) throw const EventFailure('Yer gir.');
    // Not a nicety: a session that ends before it starts is never live, never
    // clashes with a meeting slot, and shows a backwards time range on four
    // different home screens.
    if (!end.isAfter(start)) {
      throw const EventFailure('Bitiş saati başlangıçtan sonra olmalı.');
    }

    await _events.add({
      'title': title.trim(),
      'venue': venue.trim(),
      'speaker': speaker.trim(),
      'org': org.trim(),
      'kind': kind.name,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'sectors': sectors,
    });
  }

  /// Removes a session from the programme.
  ///
  /// Nothing cascades, deliberately. A saved session lives as an id on the
  /// user's own profile document, which the panel cannot write; the agenda
  /// resolves those ids against the live programme, so a deleted session simply
  /// stops resolving and drops off the agenda on its own.
  Future<void> remove(String id) => _events.doc(id).delete();
}

final eventAdminRepositoryProvider = Provider(
  (ref) => EventAdminRepository(FirebaseFirestore.instance),
);

/// The live programme, ordered as the phones order it.
final adminEventsProvider = StreamProvider<List<EventSession>>(
  (ref) => EventRepository.watch(),
);
