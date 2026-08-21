import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/organization.dart';
import 'org_card.dart';

/// One exhibitor, compact: logo, booth, name and a line about them.
///
/// Shared by every list that names companies — the visitor's kept cards, the
/// investor's watchlist, the picker a request starts from — so a company reads
/// the same wherever it appears, and its booth colour comes along with it.
class OrgRow extends StatelessWidget {
  const OrgRow({
    super.key,
    required this.organization,
    required this.onTap,
    this.caption,
    this.trailing,
    this.enabled = true,
  });

  final Organization organization;

  /// Null renders the row as unreachable rather than hiding it, which is how a
  /// company with no open hours stays visible in the picker with its reason.
  final VoidCallback? onTap;

  /// Defaults to the company's sector.
  final String? caption;

  /// Defaults to a chevron. Replaced where the row's state matters more than
  /// the fact that it opens something.
  final Widget? trailing;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = organization.color;
    final detail = caption ?? organization.sectorLabel;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          padding: const EdgeInsets.all(AppSpace.lg),
          tint: color,
          tintOpacity: enabled ? 0.12 : 0.05,
          borderColor: color.withValues(alpha: enabled ? 0.32 : 0.16),
          child: Row(
            children: [
              OrgLogo(organization: organization, size: 44),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.badgeLabel,
                      style: AppTypography.eyebrow.copyWith(color: color),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      organization.name,
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: AppTypography.bodySmall.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppPalette.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
