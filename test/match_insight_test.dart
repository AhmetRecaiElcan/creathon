import 'package:creathon/domain/card_match.dart';
import 'package:creathon/domain/match_insight.dart';
import 'package:creathon/domain/org_kind.dart';
import 'package:creathon/domain/organization.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the model's opinion and the deterministic scorer's meet.
///
/// The merge is the only place in the app that decides which number a user
/// sees, so it is tested without a widget tree or a network: the same two cards,
/// once with a verdict and once without.
void main() {
  const zeta = Organization(
    id: 'startup-1',
    kind: OrgKind.startup,
    name: 'Zeta Uzay',
    description: 'Küp uydu itki sistemleri.',
    sector: 'Havacılık & Uzay',
    stage: 'Pre-seed',
  );

  const nexora = Organization(
    id: 'startup-2',
    kind: OrgKind.startup,
    name: 'Nexora Robotik',
    description: 'Otonom seyir yazılımı.',
    sector: 'Yapay Zekâ',
    stage: 'Seed',
    market: 'Ulusal',
  );

  const criteria = MatchCriteria(
    sectors: {'Yapay Zekâ'},
    stages: {'Seed'},
    markets: {'Ulusal'},
  );

  group('MatchInsight', () {
    test('with no verdicts it is the weighted flags as a percentage', () {
      final ranked = MatchInsight.rank([zeta, nexora], criteria, const {});

      expect(ranked.first.organization.id, nexora.id);
      expect(ranked.first.percent, 100, reason: 'all three axes hit');
      expect(ranked.first.fromAi, isFalse);
      expect(ranked.last.percent, 0, reason: 'Zeta hits none of them');
    });

    test('a sector match alone clears the floor; a market match alone does not',
        () {
      final sectorOnly = MatchInsight.local(
        CardMatcher.score(nexora, const MatchCriteria(sectors: {'Yapay Zekâ'})),
      );
      final marketOnly = MatchInsight.local(
        CardMatcher.score(nexora, const MatchCriteria(markets: {'Ulusal'})),
      );

      expect(sectorOnly.matched, isTrue);
      expect(sectorOnly.percent, greaterThanOrEqualTo(MatchInsight.floor));
      expect(marketOnly.matched, isFalse);
    });

    test('a verdict replaces the score and reorders the list', () {
      final ranked = MatchInsight.rank([zeta, nexora], criteria, const {
        'startup-1': AiMatch(
          orgId: 'startup-1',
          score: 92,
          headline: 'İtki sistemleri',
          reason: 'Küp uydu itkisi savunma portföyünün tedarik zinciri.',
        ),
        'startup-2': AiMatch(
          orgId: 'startup-2',
          score: 38,
          headline: 'Etiket uyumu',
          reason: 'Etiketler tutuyor, anlattığı iş tezin dışında.',
        ),
      });

      // The model outranks the flags outright — a card that hits all three
      // criteria goes below one that hits none, because the model read them.
      expect(ranked.first.organization.id, zeta.id);
      expect(ranked.first.percent, 92);
      expect(ranked.first.fromAi, isTrue);
      expect(ranked.first.matched, isTrue);

      expect(ranked.last.percent, 38);
      expect(
        ranked.last.matched,
        isFalse,
        reason: 'the floor applies to the model too, or the two engines would '
            'mean different things by the same heading',
      );

      // The caption is the model's sentence, which is the only text here that
      // explains rather than restates.
      expect(ranked.first.caption, contains('tedarik zinciri'));
    });

    test('a partial ranking scores the rest with the flags', () {
      // Exactly what the function's candidate cap produces on a busy floor:
      // some cards came back with a verdict, the others still have to be
      // placed somewhere rather than dropped off the hall.
      final ranked = MatchInsight.rank([zeta, nexora], criteria, const {
        'startup-1': AiMatch(
          orgId: 'startup-1',
          score: 71,
          headline: 'Uzay itkisi',
          reason: 'Savunma tedarik zinciri.',
        ),
      });

      expect(ranked.map((insight) => insight.fromAi), [false, true]);
      expect(ranked.first.organization.id, nexora.id);
      expect(ranked.first.percent, 100);
      expect(ranked.last.percent, 71);
    });

    test('a row missing an id is dropped rather than trusted', () {
      expect(AiMatch.fromMap(const {'score': 90}), isNull);
      expect(
        AiMatch.fromMap(const {'id': 'a', 'score': 4000})?.score,
        100,
        reason: 'the score is clamped on the way in, not on the way out',
      );
    });
  });
}
