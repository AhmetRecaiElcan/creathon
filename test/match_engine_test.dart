import 'package:creathon/domain/attendee_profile.dart';
import 'package:creathon/domain/match_engine.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

const _startup = AttendeeProfile(
  id: 'startup',
  name: 'Deniz Karaca',
  org: 'Nexora Robotik',
  title: 'Kurucu',
  role: UserRole.entrepreneur,
  sectors: ['Savunma Teknolojileri', 'Yapay Zekâ'],
  goals: ['Yatırım almak'],
  stages: {'Seed'},
  pitch: 'Otonom seyir yazılımı.',
);

const _unrelatedStartup = AttendeeProfile(
  id: 'unrelated',
  name: 'Yusuf Bilgin',
  org: 'MediSens',
  title: 'Kurucu',
  role: UserRole.entrepreneur,
  sectors: ['Sağlık Teknolojileri'],
  goals: ['Ortak / kurucu bulmak'],
  stages: {'Prototip'},
  pitch: 'Giyilebilir biyosensör.',
);

List<MatchResult> _rankAsInvestor({
  Set<String> sectors = const {'Savunma Teknolojileri', 'Yapay Zekâ'},
  Set<String> goals = const {'Yatırım yapmak'},
  Set<String> stages = const {'Seed'},
  List<AttendeeProfile> pool = const [_startup, _unrelatedStartup],
}) {
  return MatchEngine.rank(
    role: UserRole.investor,
    sectors: sectors,
    goals: goals,
    stages: stages,
    pool: pool,
  );
}

void main() {
  group('MatchEngine', () {
    test('ranks a candidate that overlaps on sector, goal and stage', () {
      final results = _rankAsInvestor();

      expect(results.first.profile.id, 'startup');
      expect(results.first.score, greaterThan(80));
    });

    test('drops candidates below the minimum score', () {
      final results = _rankAsInvestor();

      expect(results.map((r) => r.profile.id), isNot(contains('unrelated')));
    });

    test('every reason corresponds to points that were actually awarded', () {
      final result = _rankAsInvestor().first;

      expect(result.reasons, isNotEmpty);
      for (final reason in result.reasons) {
        expect(
          reason.points,
          greaterThan(0),
          reason: 'a shown reason must have contributed to the score',
        );
      }
      // The score is capped, so reasons can sum higher — but never lower, which
      // would mean a contributing factor went unexplained.
      final explained = result.reasons.fold(0, (sum, r) => sum + r.points);
      expect(explained, greaterThanOrEqualTo(result.score));
    });

    test('explains the stage match from the investor side', () {
      final result = _rankAsInvestor().first;

      final stageReason = result.reasons
          .where((r) => r.kind == MatchReasonKind.stage)
          .toList();
      expect(stageReason, hasLength(1));
      expect(stageReason.single.text, contains('Seed'));
    });

    test('scores never exceed 100 even when every factor lines up', () {
      final generous = AttendeeProfile(
        id: 'generous',
        name: 'Test',
        org: 'Test Org',
        title: 'Kurucu',
        role: UserRole.entrepreneur,
        sectors: const [
          'Savunma Teknolojileri',
          'Yapay Zekâ',
          'Havacılık & Uzay',
          'Robotik & Otonom Sistemler',
        ],
        goals: const ['Yatırım almak', 'Mentor bulmak'],
        stages: const {'Seed'},
        pitch: 'Her faktörde örtüşen aday.',
      );

      final results = _rankAsInvestor(
        sectors: const {
          'Savunma Teknolojileri',
          'Yapay Zekâ',
          'Havacılık & Uzay',
          'Robotik & Otonom Sistemler',
        },
        goals: const {'Yatırım yapmak', 'Mentorluk vermek'},
        pool: [generous],
      );

      expect(results.single.score, lessThanOrEqualTo(100));
    });

    test('ordering is stable for candidates with equal scores', () {
      const twin = AttendeeProfile(
        id: 'twin',
        // Sorts before "Nexora Robotik" on the org tie-breaker.
        org: 'Aurora Robotik',
        name: 'Twin',
        title: 'Kurucu',
        role: UserRole.entrepreneur,
        sectors: ['Savunma Teknolojileri', 'Yapay Zekâ'],
        goals: ['Yatırım almak'],
        stages: {'Seed'},
        pitch: 'Aynı puanı alan ikinci aday.',
      );

      final first = _rankAsInvestor(pool: const [_startup, twin]);
      final reversed = _rankAsInvestor(pool: const [twin, _startup]);

      expect(first.first.score, reversed.first.score);
      expect(
        first.map((r) => r.profile.id).toList(),
        reversed.map((r) => r.profile.id).toList(),
      );
    });
  });
}
