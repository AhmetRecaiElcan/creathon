import 'package:flutter/material.dart';

import '../domain/expo_stand.dart';

/// The fair floor: one L-shaped hall, generated rather than hand-listed so the
/// aisles stay even and a row can be widened by changing one number.
///
/// Metres, origin at the top-left of the bounding box:
///
///     0                                  36
///   0 +-----------------------------------+
///     |  A5  A6  A7  A8                   |
///     |  A1  A2  A3  A4                   |
///  20 +------------------+----------------+
///     |  B3  B4          |
///     |  B1  B2          |
///  38 +------------------+
///                 ▲ giriş
abstract final class ExpoLayout {
  static const _standWidth = 6.0;
  static const _standDepth = 5.0;

  /// Booth height in metres. Only the 3D view cares, but it belongs with the
  /// rest of the hall dimensions.
  static const standHeight = 4.0;

  /// How thick the floor slab is drawn. Not a real dimension — it is what
  /// turns the outline into a solid the eye can read as an L instead of a
  /// flat quadrilateral lying at an angle.
  static const floorThickness = 1.1;

  static final hall = ExpoHall(
    name: 'L Holü',
    outline: const [
      Offset(0, 0),
      Offset(36, 0),
      Offset(36, 20),
      Offset(18, 20),
      Offset(18, 38),
      Offset(0, 38),
    ],
    entrance: const Offset(9, 38),
    stands: [
      // Long arm, four booths per row.
      ..._grid(prefix: 'A', originX: 3, originY: 12, columns: 4, rows: 1),
      ..._grid(prefix: 'A', originX: 3, originY: 3, columns: 4, rows: 1, from: 5),
      // Short arm, two booths per row.
      ..._grid(prefix: 'B', originX: 2, originY: 30, columns: 2, rows: 1),
      ..._grid(prefix: 'B', originX: 2, originY: 22, columns: 2, rows: 1, from: 3),
    ],
  );

  /// A block of booths on a regular pitch. [from] is the first number in the
  /// codes, so a second row continues where the first one stopped.
  static List<ExpoStand> _grid({
    required String prefix,
    required double originX,
    required double originY,
    required int columns,
    required int rows,
    int from = 1,
    double gapX = 2,
    double gapY = 4,
  }) {
    final stands = <ExpoStand>[];
    var index = from;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        stands.add(
          ExpoStand(
            code: '$prefix${index++}',
            x: originX + column * (_standWidth + gapX),
            y: originY + row * (_standDepth + gapY),
            width: _standWidth,
            depth: _standDepth,
          ),
        );
      }
    }
    return stands;
  }
}
