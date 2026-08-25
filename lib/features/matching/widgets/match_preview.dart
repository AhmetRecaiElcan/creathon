import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/match_insight.dart';
import '../match_providers.dart';
import 'match_score_badge.dart';

/// The last thing signup shows: who is already here for you.
///
/// The whole flow up to this point asks for answers and gives nothing back —
/// a field, a stage, a target market, and then a summary that reads them back
/// as a receipt. This is the payoff, and it is the reason the questions were
/// worth answering: three real cards from the floor, each with the percentage
/// the profile just earned it and the sentence explaining the number.
///
/// Renders nothing when there is nothing honest to show. A first account at an
/// empty fair gets no cards, and inventing an encouraging one would make every
/// percentage on every later screen worth less.
class MatchPreview extends ConsumerWidget {
  const MatchPreview({super.key, this.limit = 3});

  /// Three fits a phone without scrolling and is enough to make the point.
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final status = ref.watch(matchEngineStatusProvider);
    final top = ref
        .watch(strongMatchesProvider)
        .take(limit)
        .toList(growable: false);

    if (top.isEmpty) {
      // Still waiting on the model is worth saying; a finished ranking with
      // nothing above the floor is not — the fair is simply young.
      if (status != MatchEngineStatus.thinking) return const SizedBox.shrink();
      return GlassSurface(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: accent),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                'Eşleşmelerin hesaplanıyor…',
                style: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: accent,
      tintOpacity: 0.10,
      borderColor: accent.withValues(alpha: 0.26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
              const SizedBox(width: AppSpace.sm),
              Text('EŞLEŞME ORANLARIM', style: AppTypography.eyebrow),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Verdiğin cevaplara göre fuardaki kartlar şu an böyle sıralanıyor.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpace.lg),
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.md),
            _PreviewRow(insight: top[i]),
          ],
          const SizedBox(height: AppSpace.lg),
          MatchEngineChip(
            status: status,
            model: ref.watch(matchModelProvider),
          ),
        ],
      ),
    );
  }
}

/// One card in the preview: name, the model's reason, and the percentage.
///
/// Not an [OrgRow]: a row is tappable and opens a card sheet, and nothing on
/// the signup flow should be able to navigate away from a step that has not
/// been submitted yet.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.insight});

  final MatchInsight insight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.organization.name,
                style: AppTypography.titleSmall.copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (insight.caption case final caption?) ...[
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppPalette.textTertiary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpace.md),
        MatchScoreBadge(insight: insight),
      ],
    );
  }
}
