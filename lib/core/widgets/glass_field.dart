import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// Text input matching the frosted surfaces around it.
///
/// Material's own decoration draws a filled box with its own radius and label
/// animation, none of which survives on glass — so the field is built from a
/// bare [TextField] inside the app's own container, with the label sitting
/// permanently above it instead of floating into the border.
class GlassField extends StatelessWidget {
  const GlassField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
    this.helper,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// Micro-copy under the field, e.g. a format rule.
  final String? helper;

  /// Grows the box for a paragraph-length answer such as a description.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.eyebrow),
        const SizedBox(height: AppSpace.sm),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
            border: Border.all(color: AppPalette.stroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            textInputAction: textInputAction,
            maxLines: obscureText ? 1 : maxLines,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            cursorColor: accent,
            style: AppTypography.titleSmall,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              hintText: hint,
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppPalette.textTertiary,
              ),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: AppTypography.bodySmall.copyWith(fontSize: 12),
          ),
        ],
      ],
    );
  }
}
