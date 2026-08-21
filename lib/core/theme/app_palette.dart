import 'package:flutter/painting.dart';

/// Raw colour tokens for the dark shell.
///
/// Accent colours deliberately live on [UserRole] instead of here: the accent
/// is a function of who the user is, so it cannot be a global constant.
abstract final class AppPalette {
  /// Neutral accent used before the user picks a role, so the welcome screen
  /// does not favour any one audience.
  static const brand = Color(0xFF7C8CFF);

  /// Base canvas the aurora is painted onto.
  static const ink = Color(0xFF06060B);
  static const inkRaised = Color(0xFF0D0E16);
  static const inkOverlay = Color(0xFF14161F);

  static const textPrimary = Color(0xFFF5F6FB);
  static const textSecondary = Color(0xFFB6BACB);

  /// Only for labels and micro-copy. Kept light enough to stay legible on a
  /// glass panel over a bright patch of aurora.
  static const textTertiary = Color(0xFF8B90A6);

  static const stroke = Color(0x1FFFFFFF);
  static const strokeStrong = Color(0x38FFFFFF);

  static const danger = Color(0xFFFF5C6B);
  static const success = Color(0xFF2FD98A);
  static const warning = Color(0xFFFFB020);
}

/// Corner radii, in one place so surfaces stay in the same family.
abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

/// 4pt-based spacing scale.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}
