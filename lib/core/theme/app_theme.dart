import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  /// The only theme in the app. [accent] comes from the selected role, so the
  /// whole tree re-colours when the user switches audience.
  static ThemeData dark(Color accent) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: accent,
          onPrimary: AppPalette.ink,
          surface: AppPalette.ink,
          onSurface: AppPalette.textPrimary,
          error: AppPalette.danger,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      textTheme: AppTypography.textTheme,
      // The aurora paints the background, so the scaffold must not cover it.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppPalette.ink,
      splashColor: accent.withValues(alpha: 0.10),
      highlightColor: accent.withValues(alpha: 0.06),
      dividerColor: AppPalette.stroke,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.30),
        selectionHandleColor: accent,
      ),
    );
  }
}
