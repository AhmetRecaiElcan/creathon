import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/organization.dart';
import '../../organization/widgets/org_card.dart';

/// One exhibitor's stage talk on the visitor's home.
///
/// Leads with day and hour rather than the company: a visitor scanning this
/// list is deciding where to be at two o'clock, not browsing companies — the
/// name answers the next question, not the first one.
class PanelRow extends StatelessWidget {
  const PanelRow({
    super.key,
    required this.organization,
    required this.onTap,
  });

  final Organization organization;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = organization.color;

    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        padding: const EdgeInsets.all(AppSpace.lg),
        tint: color,
        tintOpacity: 0.12,
        borderColor: color.withValues(alpha: 0.32),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization.panelTime ?? '—',
                    style: AppTypography.titleSmall.wght(700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    organization.panelDay == null
                        ? ''
                        : '${organization.panelDay}. gün',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: color.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            OrgLogo(organization: organization, size: 38),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_rounded, size: 13, color: color),
                      const SizedBox(width: 5),
                      Text(
                        'SAHNE SUNUMU',
                        style: AppTypography.eyebrow.copyWith(
                          color: color,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    organization.name,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (organization.standCode != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Stand ${organization.standCode}',
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppPalette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
