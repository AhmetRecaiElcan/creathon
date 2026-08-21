import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/expo_stand.dart';
import 'expo_layout.dart';
import 'organization_repository.dart';

/// The hall's booths with their current occupants merged in — the single list
/// the 3D view draws from.
///
/// Occupancy is derived from the exhibitor documents rather than from the
/// reservation locks, so the floor plan shows the company's own name, colour
/// and logo, and every code without an exhibitor stays a grey placeholder.
final standPlacementsProvider = Provider<List<StandPlacement>>((ref) {
  final byStand = ref.watch(organizationsByStandProvider);

  return [
    for (final stand in ExpoLayout.hall.stands)
      StandPlacement(
        stand: stand,
        occupant: switch (byStand[stand.code]) {
          null => null,
          final organization => StandOccupant(
            organizationId: organization.id,
            company: organization.name,
            color: organization.color,
            logoBase64: organization.logoBase64,
            sector: organization.sectorLabel,
          ),
        },
      ),
  ];
});

/// Booth codes still free, in layout order. What the stand picker offers.
final freeStandCodesProvider = Provider<List<String>>((ref) {
  final taken = ref.watch(organizationsByStandProvider).keys.toSet();
  return [
    for (final stand in ExpoLayout.hall.stands)
      if (!taken.contains(stand.code)) stand.code,
  ];
});
