import 'package:flutter/foundation.dart';

import 'attendee_profile.dart';
import 'user_role.dart';

enum MatchReasonKind { sector, goal, role, stage }

/// One concrete, checkable statement about why two profiles were paired.
///
/// Requirement 5 of the brief is that the user sees the rationale, so reasons
/// are produced by the same code that produces the score — a reason can never
/// describe a factor that did not actually contribute points.
@immutable
class MatchReason {
  const MatchReason({
    required this.kind,
    required this.text,
    required this.points,
  });

  final MatchReasonKind kind;
  final String text;
  final int points;
}

@immutable
class MatchResult {
  const MatchResult({
    required this.profile,
    required this.score,
    required this.reasons,
  });

  final AttendeeProfile profile;

  /// 0–100. Not a probability; a ranking signal the user can audit via
  /// [reasons].
  final int score;

  final List<MatchReason> reasons;
}

/// Deterministic, explainable matching.
///
/// Kept as pure functions over plain values so it can be unit-tested without a
/// widget tree or a backend, and so the same scores appear in every demo run.
abstract final class MatchEngine {
  static const _pointsPerSector = 18;
  static const _maxSectorPoints = 54;
  static const _pointsPerGoal = 22;
  static const _maxGoalPoints = 44;
  static const _stagePoints = 16;

  /// Score floor for a pairing to be worth showing at all. Below this the
  /// overlap is one weak signal and surfacing it would erode trust in the list.
  static const minimumScore = 30;

  /// Goal pairs that create a reason to meet. Intentionally asymmetric-safe:
  /// every pair is listed in both directions so lookups never depend on which
  /// side is the viewer.
  static const _complementaryGoals = <String, Set<String>>{
    'Yatırım almak': {'Yatırım yapmak'},
    'Yatırım yapmak': {'Yatırım almak'},
    'Pilot proje başlatmak': {'Teknoloji tedarikçisi bulmak', 'Müşteri bulmak'},
    'Teknoloji tedarikçisi bulmak': {
      'Pilot proje başlatmak',
      'Müşteri bulmak',
    },
    'Müşteri bulmak': {'Teknoloji tedarikçisi bulmak', 'Pilot proje başlatmak'},
    'Mentor bulmak': {'Mentorluk vermek'},
    'Mentorluk vermek': {'Mentor bulmak'},
    'Ortak / kurucu bulmak': {'Ortak / kurucu bulmak'},
    'Ekibe yetenek katmak': {'Sektörü tanımak'},
    'Sektörü tanımak': {'Ekibe yetenek katmak', 'Mentorluk vermek'},
  };

  static List<MatchResult> rank({
    required UserRole role,
    required Set<String> sectors,
    required Set<String> goals,
    required Set<String> stages,
    required List<AttendeeProfile> pool,
  }) {
    final results = <MatchResult>[];

    for (final candidate in pool) {
      final reasons = <MatchReason>[];
      var score = 0;

      final sharedSectors = candidate.sectors
          .where(sectors.contains)
          .toList(growable: false);
      if (sharedSectors.isNotEmpty) {
        final points = (sharedSectors.length * _pointsPerSector).clamp(
          0,
          _maxSectorPoints,
        );
        score += points;
        reasons.add(
          MatchReason(
            kind: MatchReasonKind.sector,
            text: 'Ortak alan: ${sharedSectors.join(', ')}',
            points: points,
          ),
        );
      }

      var goalPoints = 0;
      final goalPairs = <String>[];
      for (final mine in goals) {
        final fits = _complementaryGoals[mine] ?? const <String>{};
        for (final theirs in candidate.goals) {
          if (fits.contains(theirs)) {
            goalPoints += _pointsPerGoal;
            goalPairs.add('$mine → $theirs');
          }
        }
      }
      if (goalPairs.isNotEmpty) {
        goalPoints = goalPoints.clamp(0, _maxGoalPoints);
        score += goalPoints;
        reasons.add(
          MatchReason(
            kind: MatchReasonKind.goal,
            text: 'Hedef uyumu: ${goalPairs.first}',
            points: goalPoints,
          ),
        );
      }

      final (rolePoints, roleText) = _roleFit(role, candidate.role);
      score += rolePoints;
      if (roleText != null) {
        reasons.add(
          MatchReason(
            kind: MatchReasonKind.role,
            text: roleText,
            points: rolePoints,
          ),
        );
      }

      final stageMatch = _stageFit(role, stages, candidate);
      if (stageMatch != null) {
        score += _stagePoints;
        reasons.add(
          MatchReason(
            kind: MatchReasonKind.stage,
            text: stageMatch,
            points: _stagePoints,
          ),
        );
      }

      score = score.clamp(0, 100);
      if (score < minimumScore || reasons.isEmpty) continue;

      results.add(
        MatchResult(profile: candidate, score: score, reasons: reasons),
      );
    }

    // Ties broken by name so the order is stable across rebuilds.
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.profile.org.compareTo(b.profile.org);
    });
    return results;
  }

  /// Points and wording for the role pairing. Same-role pairings score low but
  /// are not excluded — two founders in one sector still have reason to talk.
  static (int, String?) _roleFit(UserRole viewer, UserRole other) {
    if (viewer == other) {
      return (4, null);
    }
    final pair = {viewer, other};
    if (pair.containsAll({UserRole.entrepreneur, UserRole.investor})) {
      return (16, 'Girişimci–yatırımcı eşleşmesi');
    }
    if (pair.containsAll({UserRole.entrepreneur, UserRole.corporate})) {
      return (14, 'Girişimci–kurum iş birliği fırsatı');
    }
    // Weighted so that a single shared sector is enough to clear
    // [minimumScore]. The brief has investors prioritising "girişimleri ve
    // kurumları", and corporate goals rarely complement an investor's, so
    // without this corporates never surface for an investor at all.
    if (pair.containsAll({UserRole.investor, UserRole.corporate})) {
      return (14, 'Yatırımcı–kurum ortak yatırım fırsatı');
    }
    return (6, null);
  }

  /// Stage only matters where money changes hands, so it is scored for the
  /// investor–startup axis and ignored elsewhere.
  static String? _stageFit(
    UserRole viewer,
    Set<String> viewerStages,
    AttendeeProfile candidate,
  ) {
    if (viewerStages.isEmpty || candidate.stages.isEmpty) return null;

    final shared = candidate.stages.where(viewerStages.contains).toList();
    if (shared.isEmpty) return null;

    if (viewer == UserRole.investor && candidate.role == UserRole.entrepreneur) {
      return 'Aşama uyumu: ${shared.join(', ')} — yatırım aralığında';
    }
    if (viewer == UserRole.entrepreneur && candidate.role == UserRole.investor) {
      return 'Aşama uyumu: ${shared.join(', ')} aşamasına yatırım yapıyor';
    }
    return null;
  }
}
