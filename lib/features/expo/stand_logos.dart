import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/expo_repository.dart';

/// Booth logos decoded once, ready for the painter.
///
/// A [CustomPainter] can only draw a `ui.Image`, and decoding is asynchronous,
/// so it cannot happen inside `paint`. Decoding here — keyed by organisation id
/// and downsized to the largest size a booth roof ever gets — means the hall
/// repaints at sixty frames a second while it is being orbited without touching
/// a codec.
final standLogosProvider = FutureProvider<Map<String, ui.Image>>((ref) async {
  final placements = ref.watch(standPlacementsProvider);
  final logos = <String, ui.Image>{};

  for (final placement in placements) {
    final occupant = placement.occupant;
    final encoded = occupant?.logoBase64;
    if (occupant == null || encoded == null || encoded.isEmpty) continue;

    try {
      final codec = await ui.instantiateImageCodec(
        base64Decode(encoded),
        targetWidth: 128,
      );
      final frame = await codec.getNextFrame();
      logos[occupant.organizationId] = frame.image;
    } catch (error) {
      // A logo that will not decode simply leaves the booth showing its name.
      debugPrint('Stant logosu çözülemedi: $error');
    }
  }

  return logos;
});
