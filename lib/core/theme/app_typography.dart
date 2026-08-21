import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Manrope ships as a single variable font, so every weight has to be selected
/// through the `wght` axis. Setting only [TextStyle.fontWeight] leaves the axis
/// at its default and every weight renders identically — so both are always set
/// together here, and [AppTextStyleX.wght] is the only sanctioned way to change
/// a weight afterwards.
abstract final class AppTypography {
  static const family = 'Manrope';

  static TextStyle _m(
    double size,
    int wght, {
    double height = 1.30,
    double letterSpacing = 0,
    Color color = AppPalette.textPrimary,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: weightOf(wght),
      fontVariations: [FontVariation('wght', wght.toDouble())],
    );
  }

  /// `200 -> FontWeight.w200`. [FontWeight.values] is ordered w100..w900.
  static FontWeight weightOf(int wght) =>
      FontWeight.values[(wght ~/ 100).clamp(1, 9) - 1];

  /// The Take Off wordmark: very large, tight, slightly negative tracking.
  static final wordmark = _m(64, 800, height: 1.0, letterSpacing: -2.4);

  static final displayLarge = _m(40, 800, height: 1.08, letterSpacing: -1.2);
  static final displayMedium = _m(32, 700, height: 1.12, letterSpacing: -0.8);
  static final titleLarge = _m(22, 700, height: 1.20, letterSpacing: -0.4);
  static final titleMedium = _m(18, 700, height: 1.25, letterSpacing: -0.2);
  static final titleSmall = _m(16, 600, height: 1.30);
  static final bodyLarge = _m(16, 500, height: 1.45, color: AppPalette.textSecondary);
  static final bodyMedium = _m(14, 500, height: 1.50, color: AppPalette.textSecondary);
  static final bodySmall = _m(
    13,
    500,
    height: 1.45,
    color: AppPalette.textSecondary,
  );
  static final label = _m(14, 600, height: 1.20);

  /// All-caps micro label. The wide tracking is what makes it read as an
  /// eyebrow rather than as shouting.
  static final eyebrow = _m(
    11,
    700,
    height: 1.20,
    letterSpacing: 2.0,
    color: AppPalette.textTertiary,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: titleLarge,
    headlineLarge: displayMedium,
    headlineMedium: titleLarge,
    headlineSmall: titleMedium,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: label,
    labelMedium: label,
    labelSmall: eyebrow,
  );
}

extension AppTextStyleX on TextStyle {
  /// Changes weight on both the Material property and the variable-font axis.
  TextStyle wght(int w) => copyWith(
    fontWeight: AppTypography.weightOf(w),
    fontVariations: [FontVariation('wght', w.toDouble())],
  );

  TextStyle tint(Color color) => copyWith(color: color);
}
