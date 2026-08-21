import 'package:flutter/material.dart';

import '../core/util/time_format.dart';

enum SessionKind {
  keynote('Açılış Konuşması', Icons.campaign_rounded),
  panel('Panel', Icons.groups_rounded),
  workshop('Atölye', Icons.build_rounded),
  pitch('Girişim Sunumu', Icons.mic_rounded),
  networking('Networking', Icons.handshake_rounded);

  const SessionKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

@immutable
class EventSession {
  const EventSession({
    required this.id,
    required this.title,
    required this.speaker,
    required this.org,
    required this.kind,
    required this.venue,
    required this.start,
    required this.end,
    required this.sectors,
  });

  final String id;
  final String title;
  final String speaker;
  final String org;
  final SessionKind kind;

  /// Hall or stage name, matching the labels used on the venue map.
  final String venue;

  final DateTime start;
  final DateTime end;

  /// Tags from [Taxonomy.sectors]; how a session becomes personally relevant.
  final List<String> sectors;

  String get startLabel => formatHm(start);
  String get endLabel => formatHm(end);
  String get timeLabel => '$startLabel – $endLabel';

  bool isLiveAt(DateTime now) => !now.isBefore(start) && now.isBefore(end);

  /// How many of the user's interests this session covers.
  int overlapWith(Set<String> userSectors) =>
      sectors.where(userSectors.contains).length;
}
