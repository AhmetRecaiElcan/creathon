import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'glass_surface.dart';

/// Tappable pill used for every taxonomy choice in onboarding and in filters.
///
/// The selected state carries three signals at once — accent fill, accent
/// border and a check glyph — so it survives both glare and colour-blindness.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Defaults to the theme accent, which is already the role's colour.
  final Color? accent;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return PressableGlass(
      radius: AppRadius.pill,
      tint: selected ? color : Colors.white,
      tintOpacity: selected ? 0.20 : 0.06,
      borderColor: selected
          ? color.withValues(alpha: 0.60)
          : AppPalette.stroke,
      glow: selected ? color : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      semanticLabel: label,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: Icon(Icons.check_rounded, size: 16, color: color),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: Icon(icon, size: 16, color: AppPalette.textTertiary),
            ),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected ? AppPalette.textPrimary : AppPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
