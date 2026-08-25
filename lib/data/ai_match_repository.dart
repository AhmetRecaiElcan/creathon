import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/match_insight.dart';

/// A ranking from the model, and which model produced it.
@immutable
class AiRanking {
  const AiRanking({
    required this.matches,
    required this.model,
    required this.cached,
  });

  static const empty = AiRanking(matches: {}, model: '', cached: false);

  /// Keyed by organisation id, because that is how every row looks its own
  /// verdict up while it is being built.
  final Map<String, AiMatch> matches;

  /// Reported so the screen can say which model scored the list rather than
  /// asserting "yapay zekâ" and leaving the judge to take it on faith.
  final String model;

  /// True when the function served a stored ranking instead of generating one.
  final bool cached;

  bool get isEmpty => matches.isEmpty;
}

/// Gets the model's ranking of the published cards for the signed-in account.
///
/// The app deliberately cannot do this itself. Gemini authenticates with a
/// project-wide key, so a key compiled into the APK is a key anyone can spend —
/// the same reason the Jitsi signing key lives in a function. Sending it out to
/// the `aiMatch` callable also means the prompt is assembled from Firestore
/// under the admin SDK rather than from whatever the client claims its profile
/// is, and the result is cached per account so a home screen opened twice costs
/// one generation.
abstract interface class AiMatchRepository {
  /// Returns [AiRanking.empty] rather than throwing when the model is
  /// unreachable. A refusal is not an error the user can act on: the screens
  /// fall through to [CardMatcher] and the fair keeps working — which is the
  /// whole point of keeping the deterministic scorer alive.
  Future<AiRanking> rank();
}

class FunctionsAiMatchRepository implements AiMatchRepository {
  const FunctionsAiMatchRepository();

  /// Must match the region the function is deployed to, or the call lands on a
  /// URL where nothing is listening and comes back as `not-found`.
  static const region = 'europe-west1';

  @override
  Future<AiRanking> rank() async {
    if (!firebaseReady) return AiRanking.empty;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: region,
      ).httpsCallable('aiMatch');
      final result = await callable.call<Map<Object?, Object?>>();

      final rows = result.data['matches'];
      if (rows is! List) return AiRanking.empty;

      final matches = <String, AiMatch>{};
      for (final row in rows) {
        if (row is! Map) continue;
        final match = AiMatch.fromMap(row);
        if (match != null) matches[match.orgId] = match;
      }

      return AiRanking(
        matches: matches,
        model: (result.data['model'] as String?) ?? '',
        cached: (result.data['cached'] as bool?) ?? false,
      );
    } on FirebaseFunctionsException catch (error) {
      // Logged rather than surfaced: every one of these — no key configured,
      // quota spent, profile not written yet — has the same answer for the
      // user, which is the list they were going to get anyway.
      debugPrint('Yapay zekâ sıralaması alınamadı: ${error.code} '
          '${error.message}');
      return AiRanking.empty;
    } catch (error) {
      debugPrint('Yapay zekâ sıralaması alınamadı: $error');
      return AiRanking.empty;
    }
  }
}

/// Stands in for the callable in tests and in a build with no backend, so a
/// widget test of the home screen never waits on a network call.
class OfflineAiMatchRepository implements AiMatchRepository {
  const OfflineAiMatchRepository();

  @override
  Future<AiRanking> rank() async => AiRanking.empty;
}

final aiMatchRepositoryProvider = Provider<AiMatchRepository>(
  (ref) => const FunctionsAiMatchRepository(),
);
