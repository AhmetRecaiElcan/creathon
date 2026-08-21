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

  /// The third tab is where the two audiences diverge: a visitor collects a
  /// day, an exhibitor publishes a card. Same four slots either way, so the
  /// shell and its branches stay one shape.
  static List<NavDestination> destinationsFor(UserRole? role) => [
    const NavDestination(
      label: 'ANA SAYFA',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    const NavDestination(
      label: 'FUAR ALANI',
      icon: Icons.view_in_ar_outlined,
      activeIcon: Icons.view_in_ar_rounded,
    ),
    if (role == UserRole.corporate)
      const NavDestination(
        label: 'KARTIM',
        icon: Icons.qr_code_2_outlined,
        activeIcon: Icons.qr_code_2_rounded,
      )
    else
      const NavDestination(
        label: 'AJANDA',
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_month_rounded,
      ),
    const NavDestination(
      label: 'PROFİL',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = destinationsFor(ref.watch(profileProvider).role);

    return Scaffold(
      // The nav bar floats over the aurora, so content scrolls behind it rather
      // than stopping at an opaque strip.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: GlassNavBar(
          destinations: destinations,
          currentIndex: navigationShell.currentIndex,
          onSelect: (index) => navigationShell.goBranch(
            index,
            // Tapping the current tab returns it to its first route.
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
