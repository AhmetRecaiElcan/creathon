import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/user_role.dart';

/// The strip at the top of every home screen: which audience you are, and the
/// scanner.
///
/// Shared rather than repeated because the QR button is the one control a user
/// reaches for while standing in front of something, and it has to be in the
/// same corner on every portfolio's first screen.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.role,
    required this.onScan,
  });

  final UserRole role;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassSurface(
          radius: AppRadius.pill,
          blur: 14,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(role.icon, size: 14, color: role.accent),
              const SizedBox(width: 6),
              Text(
                role.label.toUpperCase(),
                style: AppTypography.eyebrow.copyWith(color: role.accent),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Scanning is the one thing a visitor does while standing in front of
        // something, so it lives on the first screen rather than behind a tab.
        Semantics(
          button: true,
          label: 'Karekod okut',
          child: GestureDetector(
            onTap: onScan,
            child: GlassSurface(
              radius: AppRadius.pill,
              blur: 14,
              tint: role.accent,
              tintOpacity: 0.16,
              borderColor: role.accent.withValues(alpha: 0.38),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 15,
                    color: role.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'QR OKUT',
                    style: AppTypography.eyebrow.copyWith(
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
