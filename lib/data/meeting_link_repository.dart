import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/meeting.dart';

/// Raised when a join link could not be issued, carrying something the user can
/// act on rather than a function name and a status code.
class JoinLinkFailure implements Exception {
  const JoinLinkFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Gets the signed link that opens an online meeting.
///
/// The app cannot build this itself. A JaaS room admits whoever presents a JWT
/// signed by the tenant's private key, so the key is the whole gate — and a key
/// shipped inside the app is a key that anyone who unzips the APK can use to
/// mint themselves an unlimited pass. The signing happens in the
/// `meetingJoinLink` function instead, which also means the check on *who may
/// join* runs somewhere the caller cannot edit: it reads the meeting, confirms
/// the caller is one of its two parties and that it was actually agreed, and
/// only then signs.
abstract interface class MeetingLinkRepository {
  Future<Uri> linkFor(Meeting meeting);
}

class FunctionsMeetingLinkRepository implements MeetingLinkRepository {
  const FunctionsMeetingLinkRepository();

  /// Must match the region the function is deployed to, or the call goes to a
  /// URL where nothing is listening and comes back as `not-found`.
  static const region = 'europe-west1';

  @override
  Future<Uri> linkFor(Meeting meeting) async {
    if (!firebaseReady) {
      throw const JoinLinkFailure(
        'Firebase bağlantısı kurulamadı. İnternetini kontrol edip tekrar dene.',
      );
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: region,
      ).httpsCallable('meetingJoinLink');
      final result = await callable.call<Map<Object?, Object?>>({
        'meetingId': meeting.id,
      });

      final url = result.data['url'] as String?;
      final parsed = url == null ? null : Uri.tryParse(url);
      if (parsed == null) {
        throw const JoinLinkFailure('Görüşme bağlantısı okunamadı.');
      }
      return parsed;
    } on FirebaseFunctionsException catch (error) {
      // The function's own refusals already say something useful in Turkish —
      // "not yet confirmed", "this meeting is not yours" — so they are passed
      // through rather than flattened into one generic apology.
      debugPrint('Görüşme bağlantısı alınamadı: ${error.code} ${error.message}');
      throw JoinLinkFailure(
        error.message?.isNotEmpty == true
            ? error.message!
            : 'Görüşme bağlantısı alınamadı. Tekrar dene.',
      );
    } on JoinLinkFailure {
      rethrow;
    } catch (error) {
      debugPrint('Görüşme bağlantısı alınamadı: $error');
      throw const JoinLinkFailure(
        'Görüşme bağlantısı alınamadı. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final meetingLinkRepositoryProvider = Provider<MeetingLinkRepository>(
  (ref) => const FunctionsMeetingLinkRepository(),
);
