import 'package:flutter/material.dart';

/// One booth footprint on the fair floor.
///
/// Coordinates are in hall metres with the origin at the top-left of the
/// bounding box, x running right and y running away from the entrance. The 3D
/// view is the only thing that turns them into pixels, so the layout stays
/// readable as a plan.
@immutable
class ExpoStand {
  const ExpoStand({
    required this.code,
    required this.x,
    required this.y,
    required this.width,
    required this.depth,
  });

  /// Shown on the empty booth and used as the Firestore document id, so an
  /// organiser assigns a company by writing to `stands/A3`.
  final String code;

  final double x;
  final double y;
  final double width;
  final double depth;

  double get centerX => x + width / 2;
  double get centerY => y + depth / 2;
}

/// What a company put in a booth. Absent until an exhibitor claims the code,
/// which is exactly what the grey placeholder boxes represent.
@immutable
class StandOccupant {
  const StandOccupant({
    required this.organizationId,
    required this.company,
    required this.color,
    this.logoBase64,
    this.sector,
  });

  /// Which exhibitor this is, so tapping the booth can open their info card.
  final String organizationId;

  final String company;

  /// The brand colour the company picked; drives the whole booth's shading.
  final Color color;

  final String? logoBase64;
  final String? sector;
}

/// A booth together with whoever is standing in it.
@immutable
class StandPlacement {
  const StandPlacement({required this.stand, this.occupant});

  final ExpoStand stand;
  final StandOccupant? occupant;

  bool get isEmpty => occupant == null;

  String get label => occupant?.company ?? stand.code;
}

/// The hall outline plus its booths.
@immutable
class ExpoHall {
  const ExpoHall({
    required this.name,
    required this.outline,
    required this.stands,
    required this.entrance,
  });

  final String name;

  /// Floor polygon in hall metres, clockwise.
  final List<Offset> outline;

  final List<ExpoStand> stands;

  /// Where visitors come in; drawn as a marked opening on the floor.
  final Offset entrance;

  Rect get bounds {
    var minX = outline.first.dx, maxX = minX;
    var minY = outline.first.dy, maxY = minY;
    for (final point in outline) {
      minX = point.dx < minX ? point.dx : minX;
      maxX = point.dx > maxX ? point.dx : maxX;
      minY = point.dy < minY ? point.dy : minY;
      maxY = point.dy > maxY ? point.dy : maxY;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
