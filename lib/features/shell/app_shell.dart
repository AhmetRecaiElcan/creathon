import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/glass_nav_bar.dart';
import '../../domain/user_role.dart';
import '../profile/profile_controller.dart';

/// Tab host for everything after onboarding.
///
/// Uses an indexed stack so each tab keeps its own state: a visitor who
/// orbited the fair hall to a particular corner and stepped over to the agenda
/// should come back to the view they left, not to a reset camera.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Branch indices, fixed for every audience because an indexed stack cannot
  /// have a different shape per role. Which of them appear in the bar, and in
  /// what order, is [destinationsFor]'s business.
  static const branchHome = 0;
  static const branchExpo = 1;
  static const branchThird = 2;
  static const branchProfile = 3;
  static const branchEvents = 4;

  /// The bar, per audience.
  ///
  /// The third slot is where the portfolios diverge: a visitor collects a day,
  /// an exhibitor publishes a card, an investor works a list of requests. The
  /// investor gets a fifth slot as well — their home is a ranked list of who is
  /// on the floor, and the programme it used to share the page with is a
  /// different job that deserves its own tab.
  static List<NavDestination> destinationsFor(UserRole? role) => [
    const NavDestination(
      label: 'ANA SAYFA',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      branch: branchHome,
    ),
    if (role == UserRole.investor)
      const NavDestination(
        label: 'ETKİNLİKLER',
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note_rounded,
        branch: branchEvents,
      ),
    const NavDestination(
      label: 'FUAR ALANI',
      icon: Icons.view_in_ar_outlined,
      activeIcon: Icons.view_in_ar_rounded,
      branch: branchExpo,
    ),
    if (role?.publishesCard ?? false)
      const NavDestination(
        label: 'KARTIM',
        icon: Icons.qr_code_2_outlined,
        activeIcon: Icons.qr_code_2_rounded,
        branch: branchThird,
      )
    else if (role == UserRole.investor)
      const NavDestination(
        label: 'GÖRÜŞMELER',
        icon: Icons.handshake_outlined,
        activeIcon: Icons.handshake_rounded,
        branch: branchThird,
      )
    else
      const NavDestination(
        label: 'AJANDA',
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_month_rounded,
        branch: branchThird,
      ),
    const NavDestination(
      label: 'PROFİL',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      branch: branchProfile,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = destinationsFor(ref.watch(profileProvider).role);

    // Which slot is lit is a lookup, not the shell's index: the two only agree
    // when the bar happens to list the branches in order.
    var current = destinations.indexWhere(
      (destination) => destination.branch == navigationShell.currentIndex,
    );
    if (current < 0) current = 0;

    return Scaffold(
      // The nav bar floats over the aurora, so content scrolls behind it rather
      // than stopping at an opaque strip.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: GlassNavBar(
          destinations: destinations,
          currentIndex: current,
          onSelect: (index) {
            final branch = destinations[index].branch;
            navigationShell.goBranch(
              branch,
              // Tapping the current tab returns it to its first route.
              initialLocation: branch == navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}
