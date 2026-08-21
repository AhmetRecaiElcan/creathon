import 'package:flutter/material.dart';

/// Cover art for the profile header.
///
/// Shipped as gradients rather than as image files: they weigh nothing, scale
/// to any header size without artefacts, and stay in the same colour family as
/// the aurora the rest of the app is painted on.
enum ProfileWallpaper {
  aurora(
    id: 'aurora',
    label: 'Aurora',
    colors: [Color(0xFFA97BFF), Color(0xFF3B2A8C), Color(0xFF0B1030)],
  ),
  nebula(
    id: 'nebula',
    label: 'Nebula',
    colors: [Color(0xFFFF6FB5), Color(0xFF6A2E8F), Color(0xFF120A2A)],
  ),
  horizon(
    id: 'horizon',
    label: 'Ufuk',
    colors: [Color(0xFFFF9F1C), Color(0xFFB4402A), Color(0xFF1A0D22)],
  ),
  orbit(
    id: 'orbit',
    label: 'Yörünge',
    colors: [Color(0xFF3B9BFF), Color(0xFF1B3E8C), Color(0xFF060B22)],
  ),
  meadow(
    id: 'meadow',
    label: 'Zümrüt',
    colors: [Color(0xFF2FD98A), Color(0xFF14614C), Color(0xFF05141B)],
  ),
  graphite(
    id: 'graphite',
    label: 'Grafit',
    colors: [Color(0xFF6E7590), Color(0xFF2A2E42), Color(0xFF0A0B12)],
  );

  const ProfileWallpaper({
    required this.id,
    required this.label,
    required this.colors,
  });

  /// Stable key for the Firestore document; never localise this.
  final String id;

  final String label;

  /// Read top-left to bottom-right.
  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );

  static ProfileWallpaper fromId(String? id) {
    for (final wallpaper in values) {
      if (wallpaper.id == id) return wallpaper;
    }
    return ProfileWallpaper.aurora;
  }
}
