import 'package:flutter/material.dart';

import 'user_role.dart';

/// Anyone the user can be matched with: a startup, a fund, or a corporate.
@immutable
class AttendeeProfile {
  const AttendeeProfile({
    required this.id,
    required this.name,
    required this.org,
    required this.title,
    required this.role,
    required this.sectors,
    required this.goals,
    required this.pitch,
    this.stages = const {},
    this.venue,
  });

  final String id;

  /// Person's name. The org is what gets matched on, but people meet people.
  final String name;

  final String org;

  /// Position at [org], e.g. "Kurucu" or "Yatırım Direktörü".
  final String title;

  final UserRole role;
  final List<String> sectors;
  final List<String> goals;

  /// Startups hold one stage; funds hold every stage they invest at.
  final Set<String> stages;

  /// One line on what this org does or looks for.
  final String pitch;

  /// Stand or booth location, when there is one to walk to.
  final String? venue;

  /// Up to two letters for the avatar, taken from the org so the visual anchor
  /// matches what the user is actually scanning the list for.
  String get initials {
    final words = org.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }
}
