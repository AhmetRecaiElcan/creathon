import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// The app's single primary action. Filled with the role accent and dark-on-
/// light, so it is the only high-contrast element on a glass screen and never
/// competes with anything else for attention.
///
/// Passing a null [onPressed] renders the disabled state, which is how the
/// onboarding steps communicate "answer this before continuing".
class AccentButton extends StatefulWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  State<AccentButton> createState() => _AccentButtonState();
}

class _AccentButtonState extends State<AccentButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final enabled = widget.onPressed != null;

    // Disabled goes neutral grey rather than a faded accent: a dimmed coloured
    // fill still reads as a live button on a dark screen.
    final labelColor = enabled ? AppPalette.ink : AppPalette.textTertiary;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.label,
          style: AppTypography.titleSmall.copyWith(color: labelColor),
        ),
        if (widget.icon != null) ...[
          const SizedBox(width: AppSpace.sm),
          Icon(widget.icon, size: 19, color: labelColor),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.975 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: enabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(accent, Colors.white, 0.18)!,
                        accent,
                      ],
                    )
                  : null,
              color: enabled ? null : Colors.white.withValues(alpha: 0.07),
              border: enabled
                  ? null
                  : Border.all(color: AppPalette.stroke),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.34),
                        blurRadius: 26,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Low-emphasis circular icon button, used for back navigation.
class GhostIconButton extends StatelessWidget {
  const GhostIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: AppPalette.stroke),
          ),
          child: Icon(icon, size: 20, color: AppPalette.textPrimary),
        ),
      ),
    );
  }
}
