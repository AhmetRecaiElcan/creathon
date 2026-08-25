import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/meeting.dart';
import '../domain/meeting_brief.dart';

/// Raised when a brief could not be prepared, carrying something the user can
/// act on rather than a function name and a status code.
class BriefFailure implements Exception {
  const BriefFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A brief, and which model wrote it.
@immutable
class BriefResult {
  const BriefResult({
    required this.brief,
    required this.model,
    required this.cached,
  });

  final MeetingBrief brief;

  /// Named on the sheet. A page of advice with no stated author is a page the
  /// reader has to decide how much to trust with nothing to go on.
  final String model;

  /// True when the function served a stored brief rather than writing one.
  final bool cached;
}

/// Prepares the signed-in account for a meeting it has already agreed to.
///
/// Unlike [AiMatchRepository], a failure here is surfaced rather than swallowed.
/// The ranking has an honest fallback — the weighted tags — so a refusal there
/// changes nothing the user asked for. This has none: somebody pressed a button
/// and is waiting for words, and a sheet that silently showed nothing would be
/// read as a broken app rather than as an unreachable model.
abstract interface class MeetingBriefRepository {
  /// Throws [BriefFailure] with a readable Turkish reason.
  Future<BriefResult> briefFor(Meeting meeting);
}

class FunctionsMeetingBriefRepository implements MeetingBriefRepository {
  const FunctionsMeetingBriefRepository();

  /// Must match the region the function is deployed to, or the call lands on a
  /// URL where nothing is listening and comes back as `not-found`.
  static const region = 'europe-west1';

  @override
  Future<BriefResult> briefFor(Meeting meeting) async {
    if (!firebaseReady) {
      throw const BriefFailure(
        'Firebase bağlantısı kurulamadı. İnternetini kontrol edip tekrar dene.',
      );
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: region,
      ).httpsCallable('meetingBrief');
      final result = await callable.call<Map<Object?, Object?>>({
        'meetingId': meeting.id,
      });

      final payload = result.data['brief'];
      final brief = payload is Map ? MeetingBrief.fromMap(payload) : null;
      if (brief == null) {
        throw const BriefFailure('Brifing okunamadı. Tekrar dene.');
      }

      return BriefResult(
        brief: brief,
        model: (result.data['model'] as String?) ?? '',
        cached: (result.data['cached'] as bool?) ?? false,
      );
    } on FirebaseFunctionsException catch (error) {
      // The function's own refusals already say something useful in Turkish —
      // "not yet confirmed", "this meeting is not yours", "no key configured" —
      // so they are passed through rather than flattened into one apology.
      debugPrint('Brifing alınamadı: ${error.code} ${error.message}');
      throw BriefFailure(
        error.message?.isNotEmpty == true
            ? error.message!
            : 'Brifing hazırlanamadı. Tekrar dene.',
      );
    } on BriefFailure {
      rethrow;
    } catch (error) {
      debugPrint('Brifing alınamadı: $error');
      throw const BriefFailure(
        'Brifing hazırlanamadı. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final meetingBriefRepositoryProvider = Provider<MeetingBriefRepository>(
  (ref) => const FunctionsMeetingBriefRepository(),
);
