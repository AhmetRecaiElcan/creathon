import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/meeting_feedback.dart';

/// Raised when a rating could not be recorded.
class FeedbackFailure implements Exception {
  const FeedbackFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ratings people left on meetings they attended.
///
/// A document lives at `meetingFeedback/{meetingId}__{authorId}`, so one rating
/// per party per meeting is enforced by the document's name — the same
/// create-only trick the booth locks and the meeting slots use, and for the
/// same reason: rules cannot check uniqueness across a collection.
///
/// Only the author reads their own. The rating is also what makes a finished
/// meeting disappear from that person's screens, which is why this is watched
/// rather than fetched once.
abstract interface class MeetingFeedbackRepository {
  static const collection = 'meetingFeedback';

  /// Everything this account has rated.
  Stream<List<MeetingFeedback>> watchByAuthor(String uid);

  Future<void> submit(MeetingFeedback feedback);
}

class FirestoreMeetingFeedbackRepository implements MeetingFeedbackRepository {
  const FirestoreMeetingFeedbackRepository();

  CollectionReference<Map<String, dynamic>> get _feedback => FirebaseFirestore
      .instance
      .collection(MeetingFeedbackRepository.collection);

  @override
  Stream<List<MeetingFeedback>> watchByAuthor(String uid) {
    if (!firebaseReady) return Stream.value(const <MeetingFeedback>[]);
    return _feedback
        .where('authorId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetingFeedback.fromMap(doc.data(), id: doc.id))
              .nonNulls
              .toList(growable: false),
        )
        // A refused query must not blank the agenda. It says the same thing an
        // empty result does: nothing has been rated yet, so nothing is hidden.
        .handleError((Object error) {
          debugPrint('Değerlendirmeler okunamadı: $error');
        });
  }

  @override
  Future<void> submit(MeetingFeedback feedback) async {
    if (!firebaseReady) {
      throw const FeedbackFailure(
        'Firebase bağlantısı kurulamadı. İnternetini kontrol edip tekrar dene.',
      );
    }
    if (!MeetingFeedback.isValidRating(feedback.rating)) {
      throw const FeedbackFailure('Bir ile beş yıldız arası bir puan ver.');
    }

    try {
      await _feedback.doc(feedback.id).set(feedback.toMap());
    } on FirebaseException catch (error) {
      // The rules allow create and nothing else, so a second rating on the
      // same meeting lands here rather than replacing the first.
      if (error.code == 'already-exists' || error.code == 'permission-denied') {
        throw const FeedbackFailure(
          'Bu görüşmeyi zaten değerlendirdin.',
        );
      }
      throw FeedbackFailure('Değerlendirme gönderilemedi: ${error.message}');
    } catch (error) {
      debugPrint('Değerlendirme gönderilemedi: $error');
      throw const FeedbackFailure(
        'Değerlendirme gönderilemedi. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final meetingFeedbackRepositoryProvider = Provider<MeetingFeedbackRepository>(
  (ref) => const FirestoreMeetingFeedbackRepository(),
);
