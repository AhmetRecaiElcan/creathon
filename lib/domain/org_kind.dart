import 'package:flutter/material.dart';

/// What kind of thing a published card describes.
///
/// The exhibitor and the startup publish the *same* card — a name, a logo, a
/// paragraph, contact channels and the hours they take meetings — so they share
/// one document shape rather than two collections that would then need two
/// scanners, two card widgets and two sets of rules. What differs is small and
/// lives here: an exhibitor holds a booth, a startup carries a stage.
enum OrgKind {
  corporate(id: 'corporate', label: 'Kurum', badge: 'KURUM'),
  startup(id: 'startup', label: 'Girişim', badge: 'GİRİŞİM');

  const OrgKind({required this.id, required this.label, required this.badge});

  /// Stable key written to Firestore; never localise this.
  final String id;

  final String label;

  /// All-caps word on the card's eyebrow, where a booth code would otherwise
  /// go — a startup has no stand, but it still has to say what it is.
  final String badge;

  bool get isStartup => this == OrgKind.startup;

  IconData get icon => switch (this) {
    OrgKind.corporate => Icons.apartment_rounded,
    OrgKind.startup => Icons.rocket_launch_rounded,
  };

  /// Defaults to [corporate], which is what every document written before the
  /// entrepreneur portfolio existed is.
  static OrgKind fromId(String? id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return OrgKind.corporate;
  }
}
