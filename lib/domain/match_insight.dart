import 'package:flutter/foundation.dart';

import 'card_match.dart';
import 'organization.dart';

/// One card's verdict from the model: how worth meeting it is, and why.
///
/// Mirrors the `aiMatch` function's response row for row. Kept as a plain value
/// so the ranking can be unit-tested without a network, and so a malformed row
/// from the wire is rejected here rather than halfway up the widget tree.
@immutable
class AiMatch {
  const AiMatch({
    required this.orgId,
    required this.score,
    required this.headline,
    required this.reason,
  });

  final String orgId;

  /// 0–100. The model's own number, clamped on the server before it is sent.
  final int score;

  /// Two or three words naming the strongest reason: `Savunma · Seed uyumu`.
  final String headline;

  /// One sentence, grounded in something the card actually says.
  final String reason;

  static AiMatch? fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) return null;
    return AiMatch(
      orgId: id,
      score: ((map['score'] as num?)?.round() ?? 0).clamp(0, 100),
      headline: ((map['headline'] as String?) ?? '').trim(),
      reason: ((map['reason'] as String?) ?? '').trim(),
    );
  }
}

/// What a list row shows about a card: a percentage, a reason, and where the
/// two came from.
///
/// The one type every ranked list reads, so the screens do not each have to
/// know whether the model answered. When it did, this carries its score and its
/// sentence; when it did not — no key, no signal, quota spent — it carries
/// [CardMatcher]'s weighted flags converted to the same scale, and [fromAi] is
/// false so the UI can stop claiming an intelligence it did not use.
@immutable
class MatchInsight {
  const MatchInsight({
    required this.organization,
    required this.percent,
    required this.fromAi,
    this.headline,
    this.reason,
  });

  /// The deterministic reading of a card: the same three flags the app has
  /// always scored, expressed as a percentage of the maximum they can reach.
  ///
  /// Deliberately coarse — seven possible values, not a hundred. It is a
  /// fallback, and pretending otherwise would be the dishonesty the old `x/3`
  /// badge was avoiding.
  MatchInsight.local(CardMatch match)
    : organization = match.organization,
      percent = (match.score * 100 / _localTotal).round(),
      fromAi = false,
      headline = match.reasons.isEmpty ? null : match.reasons.join('  ·  '),
      reason = null;

  final Organization organization;

  /// 0–100.
  final int percent;

  /// True when the number came from the model rather than from the flags.
  final bool fromAi;

  final String? headline;
  final String? reason;

  static final int _localTotal =
      CardMatcher.sectorPoints +
      CardMatcher.stagePoints +
      CardMatcher.marketPoints;

  /// Below this a card is not "for you" — it is just also at the fair.
  ///
  /// One threshold for both sources on purpose: a visitor cannot tell which
  /// engine scored a row, so two different bars for the same badge would make
  /// the section headings mean different things on different days. 40 is where
  /// a shared field alone (57%) is in and a market match alone (14%) is out.
  static const floor = 40;

  bool get matched => percent >= floor;

  /// What the row says under the name. The model's sentence when there is one,
  /// because it is the only text here that explains rather than restates;
  /// otherwise the matched labels, and failing that whatever the card declared.
  String? get caption {
    if (reason != null && reason!.isNotEmpty) return reason;
    if (headline != null && headline!.isNotEmpty) return headline;
    return organization.focusLine;
  }

  /// Merges a model verdict onto a card, keeping the deterministic labels as
  /// the headline when the model did not supply one.
  static MatchInsight ai({
    required CardMatch local,
    required AiMatch verdict,
  }) => MatchInsight(
    organization: local.organization,
    percent: verdict.score,
    fromAi: true,
    headline: verdict.headline.isNotEmpty
        ? verdict.headline
        : (local.reasons.isEmpty ? null : local.reasons.join('  ·  ')),
    reason: verdict.reason.isEmpty ? null : verdict.reason,
  );

  /// Ranks cards, using the model's score where there is one and the weighted
  /// flags where there is not.
  ///
  /// A single pass rather than "AI list, then local list" because a floor with
  /// forty cards on it can outrun the model's candidate cap: the cards past it
  /// still have to be placed somewhere, and dropping them would silently hide
  /// exhibitors from the hall.
  static List<MatchInsight> rank(
    Iterable<Organization> cards,
    MatchCriteria criteria,
    Map<String, AiMatch> verdicts,
  ) {
    final ranked = [
      for (final local in CardMatcher.rank(cards, criteria))
        if (verdicts[local.organization.id] case final verdict?)
          MatchInsight.ai(local: local, verdict: verdict)
        else
          MatchInsight.local(local),
    ]..sort((a, b) {
      final byScore = b.percent.compareTo(a.percent);
      if (byScore != 0) return byScore;
      return a.organization.name.toLowerCase().compareTo(
        b.organization.name.toLowerCase(),
      );
    });
    return ranked;
  }
}
