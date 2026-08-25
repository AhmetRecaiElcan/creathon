import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/match_insight.dart';
import '../match_providers.dart';

/// The match percentage, as a compact mark on a card row.
///
/// This is the number the old `x/3` badge refused to show, and the reason it
/// can be shown now is that something is finally reading the cards: three
/// weighted flags do not support a percentage, but a model that has read what a
/// company says it does supports one — so the badge carries a spark when the
/// score is the model's and does not when it is the flags'. Same shape either
/// way, because the honest difference is *where the number came from*, and that
/// is exactly what the icon says.
class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({super.key, required this.insight});

  final MatchInsight insight;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final strong = insight.percent >= 75;

    // A weak match is drawn down rather than out: it is still information, and
    // an investor scanning the tail of the list is reading these numbers to
    // decide where the tail begins.
    final tint = insight.matched ? accent : AppPalette.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: tint.withValues(alpha: strong ? 0.20 : 0.11),
        border: Border.all(color: tint.withValues(alpha: strong ? 0.48 : 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            insight.fromAi
                ? Icons.auto_awesome_rounded
                : Icons.percent_rounded,
            size: 11,
            color: tint,
          ),
          const SizedBox(width: 4),
          Text(
            '${insight.percent}',
            style: AppTypography.eyebrow.copyWith(
              color: tint,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Says out loud what ranked the list.
///
/// A ranked list with no stated engine is an opinion the app will not explain,
/// which is the same objection the criteria card answers for the filters. This
/// answers it for the scoring: the model's name while it is the model, and an
/// unembarrassed admission when the call did not land.
class MatchEngineChip extends StatelessWidget {
  const MatchEngineChip({
    super.key,
    required this.status,
    this.model = '',
  });

  final MatchEngineStatus status;

  /// e.g. `gemini-2.5-flash-lite`. Trimmed to the family name for display —
  /// the version is noise on a phone, and the point is which engine, not which
  /// revision.
  final String model;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    final (icon, label, tint) = switch (status) {
      MatchEngineStatus.thinking => (
        Icons.auto_awesome_rounded,
        'YAPAY ZEKÂ SIRALIYOR…',
        accent,
      ),
      MatchEngineStatus.ai => (
        Icons.auto_awesome_rounded,
        'YAPAY ZEKÂ SIRALADI${_suffix()}',
        accent,
      ),
      MatchEngineStatus.deterministic => (
        Icons.rule_rounded,
        'ETİKET EŞLEŞMESİYLE SIRALANDI',
        AppPalette.textTertiary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: tint.withValues(alpha: 0.13),
        border: Border.all(color: tint.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == MatchEngineStatus.thinking)
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: tint),
            )
          else
            Icon(icon, size: 12, color: tint),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              label,
              style: AppTypography.eyebrow.copyWith(color: tint, fontSize: 9.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// `  ·  GEMINI 2.5`, or nothing when the function reported no model.
  String _suffix() {
    final family = model.split('-').take(2).join(' ').trim();
    return family.isEmpty ? '' : '  ·  ${family.toUpperCase()}';
  }
}
