import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

const _tau = math.pi * 2;

/// One soft colour blob's motion parameters. Each blob travels a Lissajous
/// path, so with differing frequencies the composition never visibly repeats
/// even though the animation loops.
class _BlobSeed {
  const _BlobSeed({
    required this.ax,
    required this.ay,
    required this.fx,
    required this.fy,
    required this.px,
    required this.py,
    required this.radius,
  });

  /// Travel amplitude as a fraction of the canvas, from centre.
  final double ax, ay;

  /// Cycles per full animation loop. Must be whole numbers, or the blob jumps
  /// when the controller wraps back to 0.
  final double fx, fy;

  /// Phase offsets, so blobs don't start stacked on top of each other.
  final double px, py;

  /// Blob radius as a fraction of the canvas's shortest side.
  final double radius;
}

/// Wide amplitudes and moderate radii on purpose: blobs that each cover the
/// whole canvas would sit permanently on top of one another and average out
/// into a single flat wash.
const _blobSeeds = <_BlobSeed>[
  _BlobSeed(ax: .40, ay: .34, fx: 1, fy: 2, px: .00, py: .20, radius: .92),
  _BlobSeed(ax: .36, ay: .40, fx: 2, fy: 1, px: .35, py: .65, radius: .80),
  _BlobSeed(ax: .42, ay: .30, fx: 1, fy: 3, px: .62, py: .10, radius: .74),
  _BlobSeed(ax: .32, ay: .38, fx: 3, fy: 1, px: .85, py: .48, radius: .86),
  _BlobSeed(ax: .38, ay: .26, fx: 2, fy: 3, px: .15, py: .80, radius: .68),
];

/// Slow-drifting mesh gradient, the app's signature surface.
///
/// Every colour in [colors] becomes a blurred blob drifting on its own path.
/// Changing [colors] cross-fades the whole field, which is how picking a role
/// re-colours the app.
///
/// Blobs are composited with normal alpha blending rather than additively. An
/// additive pass looks richer with two blobs and blows out to flat white with
/// four, because saturated hues sum toward white — the field has to stay dark
/// enough for white text to sit on it unaided.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.colors,
    this.child,
    this.cycle = const Duration(seconds: 42),
    this.morph = const Duration(milliseconds: 1100),
    this.intensity = 0.85,
    this.baseColor = AppPalette.ink,
  });

  final List<Color> colors;
  final Widget? child;

  /// How long one full drift loop takes. Long on purpose: the motion should be
  /// noticeable only if you look for it.
  final Duration cycle;

  /// Cross-fade duration when [colors] changes.
  final Duration morph;

  /// Alpha at each blob's core. High is fine — the scrims above the blob layer
  /// are what set the overall darkness.
  final double intensity;

  final Color baseColor;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  late final AnimationController _drift;
  late final AnimationController _morph;

  late List<Color> _from;
  late List<Color> _to;

  @override
  void initState() {
    super.initState();
    _from = widget.colors;
    _to = widget.colors;
    _drift = AnimationController(vsync: this, duration: widget.cycle)..repeat();
    _morph = AnimationController(vsync: this, duration: widget.morph, value: 1);
  }

  @override
  void didUpdateWidget(AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameColors(oldWidget.colors, widget.colors)) {
      // Start the new fade from whatever is on screen right now, otherwise a
      // change mid-fade snaps back to the previous palette.
      _from = _resolveColors();
      _to = widget.colors;
      _morph
        ..duration = widget.morph
        ..forward(from: 0);
    }
  }

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Blends [_from] into [_to]. Palettes of different lengths are padded with a
  /// transparent copy of their neighbour so blobs fade in or out cleanly rather
  /// than popping.
  List<Color> _resolveColors() {
    final t = _morph.value;
    if (t >= 1) return _to;
    final count = math.max(_from.length, _to.length);
    return List<Color>.generate(count, (i) {
      final a = i < _from.length ? _from[i] : _to[i].withValues(alpha: 0);
      final b = i < _to.length ? _to[i] : _from[i].withValues(alpha: 0);
      return Color.lerp(a, b, t)!;
    }, growable: false);
  }

  @override
  void dispose() {
    _drift.dispose();
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_drift, _morph]),
        builder: (context, child) {
          return CustomPaint(
            painter: _AuroraPainter(
              t: _drift.value,
              colors: _resolveColors(),
              intensity: widget.intensity,
              baseColor: widget.baseColor,
            ),
            // Passed through AnimatedBuilder's child so it is not rebuilt on
            // every frame of the animation.
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.colors,
    required this.intensity,
    required this.baseColor,
  });

  final double t;
  final List<Color> colors;
  final double intensity;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = baseColor);

    for (var i = 0; i < colors.length; i++) {
      final seed = _blobSeeds[i % _blobSeeds.length];
      final centre = Offset(
        (0.5 + seed.ax * math.sin(_tau * (t * seed.fx + seed.px))) * size.width,
        (0.5 + seed.ay * math.cos(_tau * (t * seed.fy + seed.py))) * size.height,
      );
      // Gentle breathing so the blobs don't feel like rigid moving discs.
      final breathe = 0.90 + 0.10 * math.sin(_tau * (t * seed.fx + seed.py));
      final radius = size.shortestSide * seed.radius * breathe;
      final colour = colors[i];
      final peak = intensity * colour.a;

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(centre, radius, [
            colour.withValues(alpha: peak),
            colour.withValues(alpha: peak * 0.34),
            colour.withValues(alpha: 0),
          ], const [0.0, 0.52, 1.0]),
      );
    }

    // Pulls the colour back down to a dark field. Hue survives, brightness does
    // not — this is what keeps white text legible anywhere on screen. Tuned by
    // eye on device: heavier than this and the aurora reads as plain black.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.longestSide * 0.78,
          [
            baseColor.withValues(alpha: 0.10),
            baseColor.withValues(alpha: 0.74),
          ],
          const [0.0, 1.0],
        ),
    );

    // Extra weight at top and bottom, where the header, labels and nav bar sit.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            baseColor.withValues(alpha: 0.46),
            baseColor.withValues(alpha: 0.00),
            baseColor.withValues(alpha: 0.04),
            baseColor.withValues(alpha: 0.52),
          ],
          const [0.0, 0.26, 0.66, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t ||
      old.intensity != intensity ||
      old.baseColor != baseColor ||
      !_AuroraBackgroundState._sameColors(old.colors, colors);
}
