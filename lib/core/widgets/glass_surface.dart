import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Frosted panel used for every raised surface in the app.
///
/// Three things together are what make this read as glass rather than as a grey
/// box: the backdrop blur, a top-to-bottom white sheen (light catching an edge),
/// and a hairline border that is brighter at the top than the bottom.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.lg,
    this.blur = 24,
    this.tint,
    this.tintOpacity = 0.10,
    this.borderColor,
    this.borderWidth = 1,
    this.glow,
    this.scrimOpacity = 0.34,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;

  /// Colour mixed into the frost. Defaults to plain white for a neutral panel.
  final Color? tint;
  final double tintOpacity;

  final Color? borderColor;
  final double borderWidth;

  /// Optional coloured bloom behind the panel, for selected or accented states.
  final Color? glow;

  /// How much ink is laid under the frost.
  ///
  /// Real frosted glass over a bright scene darkens it; without this the panel
  /// interior tracks whatever the aurora is doing behind it, so the same
  /// secondary text is readable over a dark region and washed out over a bright
  /// one. The scrim makes every panel reliably darker than its background, which
  /// is what lets one set of text colours work everywhere.
  final double scrimOpacity;

  @override
  Widget build(BuildContext context) {
    final tintColor = tint ?? Colors.white;
    final border = borderColor ?? AppPalette.stroke;
    final shape = BorderRadius.circular(radius);

    Widget surface = ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            color: AppPalette.ink.withValues(alpha: scrimOpacity),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tintColor.withValues(alpha: tintOpacity),
                  tintColor.withValues(alpha: tintOpacity * 0.35),
                ],
              ),
              border: Border.all(color: border, width: borderWidth),
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );

    if (glow != null) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: glow!.withValues(alpha: 0.30),
              blurRadius: 32,
              spreadRadius: -6,
            ),
          ],
        ),
        child: surface,
      );
    }

    return surface;
  }
}

/// [GlassSurface] that dips slightly under the finger. The scale is small on
/// purpose — enough to feel physical, not enough to look like a bounce.
class PressableGlass extends StatefulWidget {
  const PressableGlass({
    super.key,
    required this.child,
    required this.onTap,
    this.padding,
    this.radius = AppRadius.lg,
    this.tint,
    this.tintOpacity = 0.10,
    this.borderColor,
    this.glow,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? tint;
  final double tintOpacity;
  final Color? borderColor;
  final Color? glow;
  final String? semanticLabel;

  @override
  State<PressableGlass> createState() => _PressableGlassState();
}

class _PressableGlassState extends State<PressableGlass> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: GlassSurface(
            radius: widget.radius,
            padding: widget.padding,
            tint: widget.tint,
            tintOpacity: widget.tintOpacity,
            borderColor: widget.borderColor,
            glow: widget.glow,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
