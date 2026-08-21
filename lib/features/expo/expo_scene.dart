import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../data/expo_layout.dart';
import '../../domain/expo_stand.dart';

/// Camera for the hall, and the projection everything else is expressed in.
///
/// Deliberately axonometric rather than perspective: a fair plan is read for
/// "which booth is next to which", and parallel aisles that stay parallel are
/// far easier to follow on a phone than a converging view. Depth still reads,
/// because the booths are extruded and shaded.
@immutable
class ExpoProjection {
  ExpoProjection({
    required this.size,
    required this.yaw,
    required this.tilt,
    required this.zoomFactor,
    required this.pan,
    required this.focus,
    required this.outline,
    required this.fitYaw,
    required this.fitTilt,
    required this.modelTop,
    required this.modelBottom,
  });

  final Size size;

  /// Rotation about the vertical axis, radians.
  final double yaw;

  /// 0 is straight down onto the floor, π/2 is eye level. The floor is
  /// compressed by cos(tilt) and the booth height scales with sin(tilt).
  final double tilt;

  /// User zoom on top of the fit-to-screen scale.
  final double zoomFactor;

  final Offset pan;

  /// Hall centre; rotation happens around this point so the model never
  /// swings out of frame while orbiting.
  final Offset focus;

  /// Hall floor polygon, used to frame the model.
  final List<Offset> outline;

  /// The camera the fit is solved for.
  ///
  /// Framing is solved once, for the default view, rather than for whatever
  /// angle the model is currently at: a fit that tracked the live silhouette
  /// would make the hall swell and shrink under the finger while orbiting.
  final double fitYaw;
  final double fitTilt;

  final double modelTop;
  final double modelBottom;

  /// Pixels per metre.
  late final double scale = _framing.scale * zoomFactor;

  late final _Framing _framing = _solveFraming();

  _Framing _solveFraming() {
    const margin = 18.0;
    final cosYaw = math.cos(fitYaw);
    final sinYaw = math.sin(fitYaw);
    final cosTilt = math.cos(fitTilt);
    final sinTilt = math.sin(fitTilt);

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;

    for (final point in outline) {
      final dx = point.dx - focus.dx;
      final dy = point.dy - focus.dy;
      final rx = dx * cosYaw - dy * sinYaw;
      final ry = dx * sinYaw + dy * cosYaw;
      // Both extremes of the model's vertical range, so the roofs of the back
      // row and the underside of the slab both stay inside the frame.
      for (final z in [modelBottom, modelTop]) {
        final sy = ry * cosTilt - z * sinTilt;
        if (rx < minX) minX = rx;
        if (rx > maxX) maxX = rx;
        if (sy < minY) minY = sy;
        if (sy > maxY) maxY = sy;
      }
    }

    final width = maxX - minX;
    final height = maxY - minY;
    if (width <= 0 || height <= 0) return const _Framing(1, Offset.zero);

    final fit = math.min(
      (size.width - margin * 2) / width,
      (size.height - margin * 2) / height,
    );
    final scale = fit.isFinite && fit > 0 ? fit : 1.0;
    // The silhouette is not symmetric about the hall centre once it is tilted,
    // so centring on the focus alone would leave the model sitting low.
    return _Framing(scale, Offset((minX + maxX) / 2, (minY + maxY) / 2));
  }

  late final double _cosYaw = math.cos(yaw);
  late final double _sinYaw = math.sin(yaw);
  late final double _cosTilt = math.cos(tilt);
  late final double _sinTilt = math.sin(tilt);
  late final Offset _origin =
      Offset(size.width / 2, size.height / 2) +
      pan -
      _framing.center * scale;

  /// Depth key: larger means nearer to the viewer, so painting in ascending
  /// order puts the far side of the hall down first.
  double depthOf(double x, double y) =>
      (x - focus.dx) * _sinYaw + (y - focus.dy) * _cosYaw;

  Offset project(double x, double y, [double z = 0]) {
    final dx = x - focus.dx;
    final dy = y - focus.dy;
    final rx = dx * _cosYaw - dy * _sinYaw;
    final ry = dx * _sinYaw + dy * _cosYaw;
    return _origin +
        Offset(rx * scale, ry * scale * _cosTilt - z * scale * _sinTilt);
  }

  /// Rotates a floor-plane direction into the same frame the faces are shaded
  /// in, so lighting stays fixed to the viewer while the hall turns.
  Offset rotateDirection(Offset direction) => Offset(
    direction.dx * _cosYaw - direction.dy * _sinYaw,
    direction.dx * _sinYaw + direction.dy * _cosYaw,
  );
}

/// Result of fitting the model to the panel: how many pixels a metre is worth,
/// and where the silhouette's centre sits in that projected space.
@immutable
class _Framing {
  const _Framing(this.scale, this.center);

  final double scale;
  final Offset center;
}

/// Interactive 3D floor plan.
///
/// One finger orbits, two fingers pan and zoom, a tap selects a booth. The
/// camera lives in this widget's state rather than in a provider so that the
/// indexed-stack shell keeps the view the visitor left behind.
class ExpoSceneView extends StatefulWidget {
  const ExpoSceneView({
    super.key,
    required this.placements,
    required this.selectedCode,
    required this.onSelect,
    this.logos = const {},
  });

  final List<StandPlacement> placements;
  final String? selectedCode;
  final ValueChanged<String?> onSelect;

  /// Decoded booth logos by organisation id, from `standLogosProvider`.
  final Map<String, ui.Image> logos;

  @override
  State<ExpoSceneView> createState() => ExpoSceneViewState();
}

class ExpoSceneViewState extends State<ExpoSceneView> {
  static const _initialYaw = -0.34;
  static const _initialTilt = 0.72;

  // The projection already fits the model to the panel at this camera, so the
  // default zoom is neutral and anything the user does is on top of a view
  // that is already framed.
  static const _initialZoom = 1.0;

  // Below ~0.35 rad the booths flatten into their own footprints; above ~1.35
  // the far row disappears behind the near one.
  static const _minTilt = 0.35;
  static const _maxTilt = 1.35;

  double _yaw = _initialYaw;
  double _tilt = _initialTilt;
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;
  double _zoomAtGestureStart = _initialZoom;

  void resetCamera() => setState(() {
    _yaw = _initialYaw;
    _tilt = _initialTilt;
    _zoom = _initialZoom;
    _pan = Offset.zero;
  });

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.pointerCount > 1) {
        _zoom = (_zoomAtGestureStart * details.scale).clamp(0.6, 3.5);
        _pan += details.focalPointDelta;
      } else {
        _yaw -= details.focalPointDelta.dx * 0.010;
        _tilt = (_tilt - details.focalPointDelta.dy * 0.006).clamp(
          _minTilt,
          _maxTilt,
        );
      }
    });
  }

  void _onTapUp(TapUpDetails details, Size size) {
    final projection = _projectionFor(size);
    // Front to back, so a tap on an overlap picks the booth in front.
    final ordered = [...widget.placements]
      ..sort(
        (a, b) => projection
            .depthOf(b.stand.centerX, b.stand.centerY)
            .compareTo(projection.depthOf(a.stand.centerX, a.stand.centerY)),
      );

    for (final placement in ordered) {
      if (_hits(projection, placement.stand, details.localPosition)) {
        widget.onSelect(
          placement.stand.code == widget.selectedCode
              ? null
              : placement.stand.code,
        );
        return;
      }
    }
    widget.onSelect(null);
  }

  static bool _hits(ExpoProjection projection, ExpoStand stand, Offset point) {
    final corners = _footprint(stand);
    // The silhouette of a convex box is covered by its top face plus its four
    // walls, so testing those five quads needs no hull computation.
    final top = [
      for (final corner in corners)
        projection.project(corner.dx, corner.dy, ExpoLayout.standHeight),
    ];
    if (_inPolygon(top, point)) return true;

    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      final wall = [
        projection.project(a.dx, a.dy),
        projection.project(b.dx, b.dy),
        projection.project(b.dx, b.dy, ExpoLayout.standHeight),
        projection.project(a.dx, a.dy, ExpoLayout.standHeight),
      ];
      if (_inPolygon(wall, point)) return true;
    }
    return false;
  }

  static List<Offset> _footprint(ExpoStand stand) => [
    Offset(stand.x, stand.y),
    Offset(stand.x + stand.width, stand.y),
    Offset(stand.x + stand.width, stand.y + stand.depth),
    Offset(stand.x, stand.y + stand.depth),
  ];

  /// Even-odd ray cast. The polygons here are small convex quads, so this is
  /// cheaper than building a Path per candidate.
  static bool _inPolygon(List<Offset> polygon, Offset point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final straddles = (a.dy > point.dy) != (b.dy > point.dy);
      if (straddles &&
          point.dx <
              (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  ExpoProjection _projectionFor(Size size) {
    final hall = ExpoLayout.hall;
    return ExpoProjection(
      size: size,
      yaw: _yaw,
      tilt: _tilt,
      zoomFactor: _zoom,
      pan: _pan,
      focus: hall.bounds.center,
      outline: hall.outline,
      fitYaw: _initialYaw,
      fitTilt: _initialTilt,
      modelTop: ExpoLayout.standHeight,
      modelBottom: -ExpoLayout.floorThickness,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onTapUp: (details) => _onTapUp(details, size),
          child: CustomPaint(
            size: size,
            painter: _ExpoPainter(
              projection: _projectionFor(size),
              placements: widget.placements,
              selectedCode: widget.selectedCode,
              accent: accent,
              logos: widget.logos,
            ),
          ),
        );
      },
    );
  }
}

class _ExpoPainter extends CustomPainter {
  _ExpoPainter({
    required this.projection,
    required this.placements,
    required this.selectedCode,
    required this.accent,
    required this.logos,
  });

  final ExpoProjection projection;
  final List<StandPlacement> placements;
  final String? selectedCode;
  final Color accent;
  final Map<String, ui.Image> logos;

  /// Colour of an unassigned booth. Neutral on purpose — a grey box is a
  /// vacancy, and the moment a company claims it the brand colour takes over.
  static const _vacant = Color(0xFF767C93);

  /// Fixed to the viewer rather than to the hall, so orbiting re-lights the
  /// booths instead of dragging the shadows around with them.
  static const _light = Offset(-0.42, 0.91);

  @override
  void paint(Canvas canvas, Size size) {
    _paintFloor(canvas);

    final ordered = [...placements]
      ..sort(
        (a, b) => projection
            .depthOf(a.stand.centerX, a.stand.centerY)
            .compareTo(projection.depthOf(b.stand.centerX, b.stand.centerY)),
      );

    for (final placement in ordered) {
      _paintStand(canvas, placement);
    }
    // Labels go on afterwards so a booth in front never clips the text of the
    // booth beside it.
    for (final placement in ordered) {
      _paintLabel(canvas, placement);
    }
  }

  void _paintFloor(Canvas canvas) {
    final hall = ExpoLayout.hall;
    _paintSlab(canvas, hall.outline);

    final floor = Path();
    for (var i = 0; i < hall.outline.length; i++) {
      final point = projection.project(
        hall.outline[i].dx,
        hall.outline[i].dy,
      );
      i == 0 ? floor.moveTo(point.dx, point.dy) : floor.lineTo(point.dx, point.dy);
    }
    floor.close();

    canvas.drawPath(
      floor,
      Paint()..color = const Color(0xFF171A28),
    );
    canvas.drawPath(
      floor,
      Paint()..color = Colors.white.withValues(alpha: 0.055),
    );

    // Grid clipped to the hall so the aisles read as a floor, not as a plane
    // the building happens to sit on.
    canvas.save();
    canvas.clipPath(floor);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final bounds = hall.bounds;
    for (var x = bounds.left; x <= bounds.right; x += 4) {
      canvas.drawLine(
        projection.project(x, bounds.top),
        projection.project(x, bounds.bottom),
        grid,
      );
    }
    for (var y = bounds.top; y <= bounds.bottom; y += 4) {
      canvas.drawLine(
        projection.project(bounds.left, y),
        projection.project(bounds.right, y),
        grid,
      );
    }
    canvas.restore();

    canvas.drawPath(
      floor,
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    _paintEntrance(canvas, hall.entrance);
  }

  /// The hall floor extruded downward into a plinth.
  ///
  /// Without it the L is a flat quadrilateral that the eye reads as a plane at
  /// an angle rather than as a building footprint; the visible thickness is
  /// what makes the shape of the hall legible at a glance.
  void _paintSlab(Canvas canvas, List<Offset> outline) {
    final bottom = -ExpoLayout.floorThickness;
    final faces = <_Wall>[];

    for (var i = 0; i < outline.length; i++) {
      final a = outline[i];
      final b = outline[(i + 1) % outline.length];
      final edge = b - a;
      final normal = Offset(edge.dy, -edge.dx);
      final length = normal.distance;
      faces.add(
        _Wall(
          a: a,
          b: b,
          depth: projection.depthOf((a.dx + b.dx) / 2, (a.dy + b.dy) / 2),
          normal: length == 0 ? Offset.zero : normal / length,
        ),
      );
    }
    faces.sort((x, y) => x.depth.compareTo(y.depth));

    for (final face in faces) {
      final a0 = projection.project(face.a.dx, face.a.dy);
      final b0 = projection.project(face.b.dx, face.b.dy);
      final bl = projection.project(face.b.dx, face.b.dy, bottom);
      final al = projection.project(face.a.dx, face.a.dy, bottom);
      final quad = Path()
        ..moveTo(a0.dx, a0.dy)
        ..lineTo(b0.dx, b0.dy)
        ..lineTo(bl.dx, bl.dy)
        ..lineTo(al.dx, al.dy)
        ..close();

      final facing = projection.rotateDirection(face.normal);
      final lambert = math.max(
        0.0,
        facing.dx * _light.dx + facing.dy * _light.dy,
      );
      canvas.drawPath(
        quad,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF090B14),
            const Color(0xFF2A2F45),
            0.25 + 0.75 * lambert,
          )!,
      );
    }
  }

  void _paintEntrance(Canvas canvas, Offset entrance) {
    // A short bright segment across the wall, plus an arrow pointing in.
    final left = projection.project(entrance.dx - 2.4, entrance.dy);
    final right = projection.project(entrance.dx + 2.4, entrance.dy);
    canvas.drawLine(
      left,
      right,
      Paint()
        ..color = accent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final tip = projection.project(entrance.dx, entrance.dy - 3.2);
    final base = projection.project(entrance.dx, entrance.dy - 0.6);
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = accent.withValues(alpha: 0.65)
        ..strokeWidth = 1.6,
    );

    _text(
      canvas,
      'GİRİŞ',
      projection.project(entrance.dx, entrance.dy + 2.6),
      AppTypography.eyebrow.copyWith(color: accent, fontSize: 9),
    );
  }

  void _paintStand(Canvas canvas, StandPlacement placement) {
    final stand = placement.stand;
    final base = placement.occupant?.color ?? _vacant;
    final selected = stand.code == selectedCode;
    final height = ExpoLayout.standHeight;

    final corners = ExpoSceneViewState._footprint(stand);

    if (selected) {
      // A soft pool of light under the booth, which reads as selection even
      // when the box itself is behind another one.
      final glow = Path();
      for (var i = 0; i < corners.length; i++) {
        final point = projection.project(corners[i].dx, corners[i].dy);
        i == 0
            ? glow.moveTo(point.dx, point.dy)
            : glow.lineTo(point.dx, point.dy);
      }
      glow.close();
      canvas.drawPath(
        glow,
        Paint()
          ..color = accent.withValues(alpha: 0.55)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18),
      );
    }

    // Walls painted back to front; the box is convex, so this needs no culling.
    final walls = <_Wall>[];
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      final edge = b - a;
      // Outward normal of a clockwise footprint.
      final normal = Offset(edge.dy, -edge.dx);
      final length = normal.distance;
      walls.add(
        _Wall(
          a: a,
          b: b,
          depth: projection.depthOf((a.dx + b.dx) / 2, (a.dy + b.dy) / 2),
          normal: length == 0 ? Offset.zero : normal / length,
        ),
      );
    }
    walls.sort((x, y) => x.depth.compareTo(y.depth));

    for (final wall in walls) {
      final a0 = projection.project(wall.a.dx, wall.a.dy);
      final b0 = projection.project(wall.b.dx, wall.b.dy);
      final bh = projection.project(wall.b.dx, wall.b.dy, height);
      final ah = projection.project(wall.a.dx, wall.a.dy, height);
      final quad = Path()
        ..moveTo(a0.dx, a0.dy)
        ..lineTo(b0.dx, b0.dy)
        ..lineTo(bh.dx, bh.dy)
        ..lineTo(ah.dx, ah.dy)
        ..close();

      final facing = projection.rotateDirection(wall.normal);
      final lambert = math.max(0.0, facing.dx * _light.dx + facing.dy * _light.dy);
      final shade = 0.34 + 0.42 * lambert;

      canvas.drawPath(
        quad,
        Paint()
          ..color = Color.lerp(Colors.black, base, shade)!.withValues(
            alpha: placement.isEmpty ? 0.82 : 0.95,
          ),
      );
    }

    // Top face: the surface the name and the brand colour actually live on.
    final top = Path();
    for (var i = 0; i < corners.length; i++) {
      final point = projection.project(corners[i].dx, corners[i].dy, height);
      i == 0 ? top.moveTo(point.dx, point.dy) : top.lineTo(point.dx, point.dy);
    }
    top.close();

    canvas.drawPath(
      top,
      Paint()..color = Color.lerp(base, Colors.white, 0.22)!,
    );
    canvas.drawPath(
      top,
      Paint()
        ..color = selected
            ? accent
            : Colors.white.withValues(alpha: placement.isEmpty ? 0.22 : 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.4 : 1,
    );
  }

  void _paintLabel(Canvas canvas, StandPlacement placement) {
    final stand = placement.stand;
    final center = projection.project(
      stand.centerX,
      stand.centerY,
      ExpoLayout.standHeight,
    );
    final occupant = placement.occupant;

    // Text stays upright rather than lying on the roof: a fair map is scanned,
    // and skewed labels cost more legibility than the extra realism buys.
    if (occupant == null) {
      _text(
        canvas,
        stand.code,
        center,
        AppTypography.eyebrow.copyWith(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 10,
          letterSpacing: 1,
        ),
      );
      return;
    }

    // How wide the booth is on screen decides what fits on its roof.
    final left = projection.project(
      stand.x,
      stand.centerY,
      ExpoLayout.standHeight,
    );
    final right = projection.project(
      stand.x + stand.width,
      stand.centerY,
      ExpoLayout.standHeight,
    );
    final boothWidth = (right - left).distance;

    // The logo is the label. A hall of names is a list read one row at a time;
    // a hall of marks is scanned at a glance, which is what a visitor standing
    // in it actually does. The name is still one tap away on the card.
    final logo = logos[occupant.organizationId];
    if (logo != null && boothWidth > 26) {
      final side = (boothWidth * 0.68).clamp(18.0, 62.0);
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromCenter(center: center, width: side, height: side),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }

    // No logo uploaded: the name has to carry the booth on its own.
    _text(
      canvas,
      occupant.company,
      center,
      AppTypography.label.copyWith(
        fontSize: 11,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
      ),
      maxWidth: 96,
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    TextStyle style, {
    double maxWidth = 120,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_ExpoPainter old) =>
      old.projection.yaw != projection.yaw ||
      old.projection.tilt != projection.tilt ||
      old.projection.scale != projection.scale ||
      old.projection.pan != projection.pan ||
      old.selectedCode != selectedCode ||
      old.placements != placements ||
      old.accent != accent ||
      old.logos != logos;
}

/// One side of a booth, kept with the numbers the painter sorts and shades by.
@immutable
class _Wall {
  const _Wall({
    required this.a,
    required this.b,
    required this.depth,
    required this.normal,
  });

  final Offset a;
  final Offset b;
  final double depth;
  final Offset normal;
}
