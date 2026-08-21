import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';

/// The one control that starts a meeting request from a list rather than from a
/// scan.
///
/// Given the weight of a card instead of a button, and shared between the
/// investor's tab and the founder's home: both audiences do the same thing here,
/// and it is the single most valuable action either of them takes in the app.
class NewRequestAction extends StatelessWidget {
  const NewRequestAction({
    super.key,
    required this.onTap,
    this.title = 'Görüşme talebi oluştur',
    this.subtitle = 'Kurumun açtığı saatlerden birini seç ve notunu yaz.',
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return PressableGlass(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: accent,
      tintOpacity: 0.16,
      borderColor: accent.withValues(alpha: 0.42),
      glow: accent,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: accent.withValues(alpha: 0.22),
              border: Border.all(color: accent.withValues(alpha: 0.46)),
            ),
            child: Icon(Icons.add_rounded, size: 21, color: accent),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodySmall),
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
    );
  }
}
