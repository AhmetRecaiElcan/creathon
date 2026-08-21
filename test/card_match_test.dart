import 'package:creathon/domain/card_match.dart';
import 'package:creathon/domain/org_kind.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ranking an investor's home screen is built on.
///
/// Pure functions over plain values, so the weights can be pinned down without
/// a widget tree — and so the order the investor sees is the order the test
/// asserts, not an accident of how the list was built.
void main() {
  Organization card({
    required String id,
    required String name,
    String? sector,
    String? stage,
    String? market,
    OrgKind kind = OrgKind.startup,
  }) => Organization(
    id: id,
    kind: kind,
    name: name,
    email: 'iletisim@$id.com',
    description: 'Açıklama.',
    sector: sector,
    stage: stage,
    market: market,
  );

  const criteria = MatchCriteria(
    sectors: {'Yapay Zekâ'},
    stages: {'Seed', 'Seri A'},
    markets: {'Ulusal'},
  );

  test('the field outweighs the level, and the level the market', () {
    final sectorOnly = CardMatcher.score(
      card(id: 'a', name: 'A', sector: 'Yapay Zekâ'),
      criteria,
    );
    final stageAndMarket = CardMatcher.score(
      card(id: 'b', name: 'B', stage: 'Seed', market: 'Ulusal'),
      criteria,
    );

    expect(sectorOnly.score, CardMatcher.sectorPoints);
    expect(stageAndMarket.score, greaterThan(0));
    expect(
      sectorOnly.score,
      greaterThan(stageAndMarket.score),
      reason: 'a shared field is worth more than a level and a market together',
    );
  });

  test('every point earned is named as a reason', () {
    final match = CardMatcher.score(
      card(
        id: 'c',
        name: 'C',
        sector: 'Yapay Zekâ',
        stage: 'Seed',
        market: 'Global',
      ),
      criteria,
    );

    expect(match.score, CardMatcher.sectorPoints + CardMatcher.stagePoints);
    expect(match.reasons, ['Yapay Zekâ', 'Seed']);
    expect(
      match.reasons,
      isNot(contains('Global')),
      reason: 'a reason may never describe a factor that scored nothing',
    );
    expect(match.caption, 'Yapay Zekâ  ·  Seed');
  });

  test('a card that matches nothing still describes itself', () {
    final match = CardMatcher.score(
      card(
        id: 'd',
        name: 'D',
        sector: 'Sağlık Teknolojileri',
        stage: 'Fikir',
        market: 'Yerel',
      ),
      criteria,
    );

    expect(match.matched, isFalse);
    expect(match.reasons, isEmpty);
    expect(
      match.caption,
      'Fikir  ·  Yerel  ·  Sağlık Teknolojileri',
      reason: 'an unmatched row falls back to what the card declared',
    );
  });

  test('ranking is best first and stable on ties', () {
    final ranked = CardMatcher.rank([
      card(id: '1', name: 'Zeta', sector: 'Yapay Zekâ'),
      card(id: '2', name: 'Alfa', sector: 'Yapay Zekâ'),
      card(
        id: '3',
        name: 'Omega',
        sector: 'Yapay Zekâ',
        stage: 'Seed',
        market: 'Ulusal',
      ),
      card(id: '4', name: 'Beta', sector: 'Fintek'),
    ], criteria);

    expect(
      ranked.map((match) => match.organization.name),
      ['Omega', 'Alfa', 'Zeta', 'Beta'],
      reason: 'full match first, then equal scores alphabetically',
    );
  });

  test('an account that answered nothing sees every card, ranked by none', () {
    const nothing = MatchCriteria();
    expect(nothing.isEmpty, isTrue);

    final ranked = CardMatcher.rank([
      card(id: '1', name: 'Alfa', sector: 'Yapay Zekâ', stage: 'Seed'),
      card(id: '2', name: 'Beta', sector: 'Fintek'),
    ], nothing);

    expect(ranked, hasLength(2));
    expect(ranked.every((match) => !match.matched), isTrue);
  });

  test('criteria come off the profile the signup wrote', () {
    const profile = UserProfile(
      role: UserRole.investor,
      sectors: {'Yapay Zekâ'},
      stages: {'Seed'},
      markets: {'Ulusal', 'Global'},
    );

    final criteria = MatchCriteria.of(profile);
    expect(criteria.sectors, {'Yapay Zekâ'});
    expect(criteria.stages, {'Seed'});
    expect(criteria.markets, {'Ulusal', 'Global'});
  });
}
