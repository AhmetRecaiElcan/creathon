import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/glass_nav_bar.dart';
import '../meetings/meetings_controller.dart';
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

  /// Görüşmeler for the card-publishing audiences.
  ///
  /// A branch of its own rather than the investor's: their third slot is
  /// already taken by KARTIM, and the indexed stack's shape is fixed for every
  /// role — so the only way a company gets a meetings tab is a new branch that
  /// the other bars simply never name.
  static const branchMeetings = 5;

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
    // Both card-publishing audiences get a meetings tab of their own, for the
    // same reason the investor has one: a meeting buried part-way down the home
    // screen is a meeting whose end-and-rate button nobody finds.
    if (role?.publishesCard ?? false)
      const NavDestination(
        label: 'GÖRÜŞMELER',
        icon: Icons.handshake_outlined,
        activeIcon: Icons.handshake_rounded,
        branch: branchMeetings,
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
    // Keeps the meeting streams subscribed for the whole signed-in session.
    //
    // Not decoration: `organizationSlotsProvider` checks a candidate hour
    // against this account's own meetings, and a provider nothing is watching
    // comes back empty on its first read. While the home screen listed
    // meetings it was subscribed by accident; the moment those sections moved
    // to their own tab, a request sheet opened cold would compute its clashes
    // against nothing and offer an hour the account had already booked. The
    // write still refuses it — the slot is a document id — but the grid would
    // have lied first. The shell is the one widget alive for as long as any of
    // this matters.
    ref.watch(meetingsProvider);

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
