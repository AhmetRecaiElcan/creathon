import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/meeting.dart';

/// Raised when a slot was claimed by someone else first.
class SlotTakenFailure implements Exception {
  const SlotTakenFailure(this.label);

  final String label;

  @override
  String toString() => '$label için başka bir talep zaten gönderilmiş.';
}

/// Raised when the write was refused for any other reason.
class MeetingFailure implements Exception {
  const MeetingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Meeting requests between visitors and exhibitors.
///
/// A document lives at `meetings/{orgId}__{startIso}`, so the slot itself is
/// what can only be claimed once — the same trick the booth reservations use,
/// and for the same reason: rules can compare fields inside one document but
/// cannot enforce uniqueness across a collection.
abstract interface class MeetingRepository {
  static const collection = 'meetings';

  /// Meetings this visitor asked for.
  Stream<List<Meeting>> watchForRequester(String uid);

  /// Requests addressed to this exhibitor.
  Stream<List<Meeting>> watchForOrganization(String orgId);

  Future<void> request(Meeting meeting);

  /// The exhibitor's answer. Declining removes the record so the slot opens
  /// back up — a refused request that blocked the time forever would make the
  /// availability grid lie.
  Future<void> respond(Meeting meeting, MeetingStatus status);
}

class FirestoreMeetingRepository implements MeetingRepository {
  const FirestoreMeetingRepository();

  CollectionReference<Map<String, dynamic>> get _meetings =>
      FirebaseFirestore.instance.collection(MeetingRepository.collection);

  @override
  Stream<List<Meeting>> watchForRequester(String uid) =>
      _watch('requesterId', uid);

  @override
  Stream<List<Meeting>> watchForOrganization(String orgId) =>
      _watch('organizationId', orgId);

  Stream<List<Meeting>> _watch(String field, String value) {
    if (!firebaseReady) return Stream.value(const <Meeting>[]);
    return _meetings
        .where(field, isEqualTo: value)
        .snapshots()
        .map((snapshot) {
          final meetings = snapshot.docs
              .map((doc) => Meeting.fromMap(doc.data(), id: doc.id))
              .nonNulls
              .toList();
          meetings.sort((a, b) => a.start.compareTo(b.start));
          return meetings;
        })
        // A refused query — rules not published yet, or an unverified account
        // — must not surface as a broken screen. It says the same thing an
        // empty result does from the user's side: no meetings to show.
        .handleError((Object error) {
          debugPrint('Toplantılar okunamadı: $error');
        });
  }

  @override
  Future<void> request(Meeting meeting) async {
    if (!firebaseReady) {
      throw const MeetingFailure(
        'Firebase bağlantısı kurulamadı. İnternetini kontrol edip tekrar dene.',
      );
    }

    final doc = _meetings.doc(meeting.id);
    try {
      // The rules allow only `create` here, so this set() on a slot someone
      // else already claimed comes back refused instead of overwriting their
      // request. Without that rule a second visitor would silently replace the
      // first one's meeting.
      await doc.set(meeting.toMap());
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists') {
        throw SlotTakenFailure(meeting.startLabel);
      }
      if (error.code != 'permission-denied') {
        throw MeetingFailure('Talep gönderilemedi: ${error.message}');
      }
      throw await _explain(doc, meeting.startLabel);
    }
  }

  /// permission-denied covers both "someone booked this slot" and "the rules
  /// are not published", and the two need different answers.
  Future<Exception> _explain(
    DocumentReference<Map<String, dynamic>> doc,
    String label,
  ) async {
    try {
      if ((await doc.get()).exists) return SlotTakenFailure(label);
    } catch (_) {
      // Even the read was refused, which points at the rules.
    }
    return const MeetingFailure(
      'Firestore bu talebi reddetti. Güncel güvenlik kurallarının yayında '
      'olduğunu ve e-posta adresinin doğrulandığını kontrol et.',
    );
  }

  @override
  Future<void> respond(Meeting meeting, MeetingStatus status) async {
    if (!firebaseReady) return;
    try {
      if (status == MeetingStatus.declined) {
        await _meetings.doc(meeting.id).delete();
        return;
      }
      await _meetings.doc(meeting.id).update({'status': status.name});
    } catch (error) {
      debugPrint('Toplantı güncellenemedi: $error');
    }
  }
}

final meetingRepositoryProvider = Provider<MeetingRepository>(
  (ref) => const FirestoreMeetingRepository(),
);
