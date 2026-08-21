import 'package:flutter/material.dart';

/// Brand colours an exhibitor can claim for its stand.
///
/// A fixed palette rather than a free colour wheel: every one of these is
/// checked to stay legible as a lit box on the dark hall floor and against
/// white label text. A picker would let a company choose a near-black that
/// disappears, or a neon that fights every neighbour.
enum BrandColor {
  azure(id: 'azure', label: 'Gök', color: Color(0xFF3B9BFF)),
  emerald(id: 'emerald', label: 'Zümrüt', color: Color(0xFF2FD98A)),
  amber(id: 'amber', label: 'Kehribar', color: Color(0xFFFF9F1C)),
  violet(id: 'violet', label: 'Menekşe', color: Color(0xFFA97BFF)),
  crimson(id: 'crimson', label: 'Kızıl', color: Color(0xFFFF5C6B)),
  teal(id: 'teal', label: 'Deniz', color: Color(0xFF19C8C8)),
  magenta(id: 'magenta', label: 'Fuşya', color: Color(0xFFFF6FB5)),
  slate(id: 'slate', label: 'Çelik', color: Color(0xFF8C93AE));

  const BrandColor({
    required this.id,
    required this.label,
    required this.color,
  });

  /// Stable key for the Firestore document; never localise this.
  final String id;

  final String label;
  final Color color;

  /// `#RRGGBB`, the form written to Firestore so a colour is readable by any
  /// client — including tools that never load this enum.
  String get hex =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static BrandColor fromId(String? id) {
    for (final brand in values) {
      if (brand.id == id) return brand;
    }
    return BrandColor.azure;
  }

  /// Matches a stored hex back to the palette, so a colour written by another
  /// tool still selects the right chip in the picker.
  static BrandColor fromHex(String? hex) {
    if (hex == null) return BrandColor.azure;
    final wanted = hex.trim().replaceFirst('#', '').toUpperCase();
    for (final brand in values) {
      if (brand.hex.substring(1) == wanted) return brand;
    }
    return BrandColor.azure;
  }
}
