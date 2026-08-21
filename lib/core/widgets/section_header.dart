import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// All-caps section label with a rule that runs out toward the edge, so the eye
/// keeps travelling across the screen instead of stopping at the text.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});

  final String label;

  /// Optional right-aligned affordance, e.g. a count or a "see all" action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Flexible so an unusually long label ellipsizes rather than pushing the
        // trailing count off the edge.
        Flexible(
          child: Text(
            label,
            style: AppTypography.eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppPalette.strokeStrong, Color(0x00FFFFFF)],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpace.md), trailing!],
      ],
    );
  }
}
