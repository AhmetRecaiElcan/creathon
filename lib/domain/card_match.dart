import 'package:flutter/foundation.dart';

import 'organization.dart';
import 'user_profile.dart';

/// What an account said it is looking for.
///
/// Three axes, in the order they were asked at signup: the field, the maturity
/// level, and how far the company means to reach. An empty set on any axis means
/// "no preference" — it scores nothing rather than excluding everything, so an
/// account that skipped a question still sees the whole hall.
@immutable
class MatchCriteria {
  const MatchCriteria({
    this.sectors = const {},
    this.stages = const {},
    this.markets = const {},
  });

  MatchCriteria.of(UserProfile profile)
    : sectors = profile.sectors,
      stages = profile.stages,
      markets = profile.markets;

  final Set<String> sectors;
  final Set<String> stages;
  final Set<String> markets;

  bool get isEmpty => sectors.isEmpty && stages.isEmpty && markets.isEmpty;
}

/// One card scored against those criteria, together with the reasons.
///
/// The reasons are produced by the same pass that produces the score, so the
/// line shown under a card can never claim a match that did not earn a point.
/// That matters more here than the score does: an investor scrolling a ranked
/// list has to be able to see *why* something is at the top, or the ranking is
/// just an opinion the app refuses to explain.
@immutable
class CardMatch {
  const CardMatch({
    required this.organization,
    required this.score,
    required this.reasons,
  });

  final Organization organization;
  final int score;

  /// The matched labels, strongest axis first: `['Yapay Zekâ', 'Seed']`.
  final List<String> reasons;

  bool get matched => score > 0;

  /// What the row says under the name: the matched labels when there are any,
  /// otherwise whatever the card declared about itself.
  String? get caption =>
      reasons.isEmpty ? organization.focusLine : reasons.join('  ·  ');
}

/// Ranks published cards against what an account is looking for.
///
/// Weights rather than a formula because the axes are not equal: two companies
/// in the same field are worth meeting whatever their size, a level match saves
/// a conversation that could not have happened, and the market is a tie-break.
///
/// 4 / 2 / 1, so that a shared field alone (4) still outranks a level *and* a
/// market in an unrelated field (3). That ordering is the whole point: an
/// investor screens on the field first, and a Seed-stage national company in
/// the wrong sector is not the top of anybody's list.
abstract final class CardMatcher {
  static const sectorPoints = 4;
  static const stagePoints = 2;
  static const marketPoints = 1;

  static CardMatch score(Organization organization, MatchCriteria criteria) {
    var score = 0;
    final reasons = <String>[];

    final sector = organization.sectorLabel;
    if (sector != null && criteria.sectors.contains(sector)) {
      score += sectorPoints;
      reasons.add(sector);
    }

    final stage = organization.stageLabel;
    if (stage != null && criteria.stages.contains(stage)) {
      score += stagePoints;
      reasons.add(stage);
    }

    final market = organization.marketLabel;
    if (market != null && criteria.markets.contains(market)) {
      score += marketPoints;
      reasons.add(market);
    }

    return CardMatch(
      organization: organization,
      score: score,
      reasons: reasons,
    );
  }

  /// Best first, then alphabetical — a stable order, so the list does not
  /// reshuffle itself between two builds that scored the same.
  static List<CardMatch> rank(
    Iterable<Organization> cards,
    MatchCriteria criteria,
  ) {
    final ranked = [
      for (final card in cards) score(card, criteria),
    ]..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.organization.name.toLowerCase().compareTo(
        b.organization.name.toLowerCase(),
      );
    });
    return ranked;
  }
}
