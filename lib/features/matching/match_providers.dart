import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai_match_repository.dart';
import '../../data/organization_repository.dart';
import '../../domain/card_match.dart';
import '../../domain/match_insight.dart';
import '../profile/profile_controller.dart';

/// What the ranking is currently backed by.
///
/// Shown on the screens that rank, because "yapay zekâ sıraladı" is a claim and
/// a claim needs a state: it is either still being computed, it happened, or it
/// did not and the deterministic scorer stood in. Hiding the third case would
/// mean the badge lies exactly when the network does.
enum MatchEngineStatus { thinking, ai, deterministic }

/// A string that changes when — and only when — the ranking would.
///
/// The model call hangs off this rather than off the card list directly. The
/// exhibitor collection is a live snapshot: someone editing a phone number
/// three booths away pushes a new list to every device, and a future watching
/// that list would re-rank the hall each time. Watching a derived string means
/// Riverpod compares it, finds it equal, and nothing downstream moves.
///
/// Empty when there is nothing to rank — no account yet, or no cards published
/// — which is the signal not to call at all.
final matchSignatureProvider = Provider<String>((ref) {
  final profile = ref.watch(profileProvider);
  final cards = ref.watch(organizationsProvider);
  if (profile.uid == null || cards.isEmpty) return '';

  final ids = [for (final card in cards) card.id]..sort();
  final sectors = profile.sectors.toList()..sort();
  final stages = profile.stages.toList()..sort();
  final markets = profile.markets.toList()..sort();

  return [
    profile.uid,
    profile.role?.id,
    sectors.join(','),
    stages.join(','),
    markets.join(','),
    ids.join(','),
  ].join('|');
});

/// The model's verdicts, one call per meaningful change to the inputs.
///
/// Never fails: [AiMatchRepository.rank] answers a refusal with an empty
/// ranking, so a screen watching this gets a value in every case and the
/// fallback happens by having nothing to merge rather than by catching.
final aiRankingProvider = FutureProvider<AiRanking>((ref) async {
  final signature = ref.watch(matchSignatureProvider);
  if (signature.isEmpty) return AiRanking.empty;
  // Read, not watch: the signature above is the only thing that should be able
  // to trigger another call.
  return ref.read(aiMatchRepositoryProvider).rank();
});

final matchEngineStatusProvider = Provider<MatchEngineStatus>((ref) {
  final ranking = ref.watch(aiRankingProvider);
  if (ranking.isLoading) return MatchEngineStatus.thinking;
  return (ranking.value?.isEmpty ?? true)
      ? MatchEngineStatus.deterministic
      : MatchEngineStatus.ai;
});

/// Which model scored the list, for the screens that name it. Empty when the
/// deterministic scorer is the one that ran.
final matchModelProvider = Provider<String>(
  (ref) => ref.watch(aiRankingProvider).value?.model ?? '',
);

/// Every published card, ranked for whoever is signed in.
///
/// The account's own card is dropped rather than scored: a founder does not
/// need to be told how well their venture matches itself, and leaving it in
/// would put it at the top of their own list every single time.
final matchInsightsProvider = Provider<List<MatchInsight>>((ref) {
  final profile = ref.watch(profileProvider);
  final verdicts = ref.watch(aiRankingProvider).value?.matches ?? const {};

  return MatchInsight.rank(
    ref
        .watch(organizationsProvider)
        .where((organization) => organization.id != profile.uid),
    MatchCriteria.of(profile),
    verdicts,
  );
});

/// The cards worth putting under a "senin için" heading.
final strongMatchesProvider = Provider<List<MatchInsight>>(
  (ref) => ref
      .watch(matchInsightsProvider)
      .where((insight) => insight.matched)
      .toList(growable: false),
);

/// Everything else at the fair, in the same ranked order.
final otherMatchesProvider = Provider<List<MatchInsight>>(
  (ref) => ref
      .watch(matchInsightsProvider)
      .where((insight) => !insight.matched)
      .toList(growable: false),
);
