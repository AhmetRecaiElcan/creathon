import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/user_role.dart';

import '../../features/agenda/agenda_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/expo/expo_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/investor_home_screen.dart';
import '../../features/meetings/investor_meetings_screen.dart';
import '../../features/meetings/meetings_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/organization/org_card_screen.dart';
import '../../features/organization/org_profile_screen.dart';
import '../../features/organization/organization_controller.dart';
import '../../features/profile/profile_controller.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/welcome/welcome_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // The tabs are built on a verified account and a set of interests, so a
    // half-finished profile cannot render them — e.g. after a hot restart or a
    // deep link straight to /home. Each gate sends the user to the earliest
    // screen that can still collect what is missing.
    redirect: (context, state) {
      final profile = ref.read(profileProvider);
      final location = state.matchedLocation;

      if (profile.role == null) return location == '/' ? null : '/';
      if (!ref.read(onboardedProvider)) {
        return location == '/onboarding' ? null : '/onboarding';
      }
      // A restored session lands on '/' at startup with nothing left to ask,
      // so send it straight into the app. '/onboarding' is excluded because
      // the profile becomes complete on the interests step, and forwarding
      // from there would skip the summary the user has not seen yet.
      if (location == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => _page(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) => _page(state, const OnboardingScreen()),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) =>
            _page(state, AppShell(navigationShell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const _RoleScreen(
                  visitor: HomeScreen(),
                  corporate: HomeScreen(),
                  // The investor's front page is a ranked list of who is on the
                  // floor rather than a feed of what is happening; the feed
                  // lives on their own /events tab.
                  investor: InvestorHomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/expo', builder: (_, _) => const ExpoScreen()),
            ],
          ),
          // Third and fourth tabs are role-dependent. The branch structure has
          // to be fixed for the indexed stack, so the route stays the same and
          // the widget behind it is chosen by role.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                builder: (_, _) => const _RoleScreen(
                  visitor: AgendaScreen(),
                  corporate: OrgCardScreen(),
                  investor: InvestorMeetingsScreen(),
                  // The founder's card is the exhibitor's card: same widget,
                  // same QR, same editing — only the contents differ.
                  entrepreneur: OrgCardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const _RoleScreen(
                  visitor: ProfileScreen(),
                  corporate: OrgProfileScreen(),
                  // Meeting hours and the way out — the same account settings
                  // the exhibitor gets, minus the booth.
                  entrepreneur: OrgProfileScreen(),
                ),
              ),
            ],
          ),
          // Fifth branch, in the bar for the investor only. It exists for every
          // role because an indexed stack's branches are fixed — the others
          // simply never have a tab pointing at it.
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/events', builder: (_, _) => const EventsScreen()),
            ],
          ),
          // Sixth branch: görüşmeler for the company and the founder. The
          // investor's own meetings screen stays on the third branch — theirs is
          // a different page, built around a fund that publishes no card.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/meetings',
                builder: (_, _) => const MeetingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Picks a screen by audience.
///
/// All of them are built as constants and only one is mounted, so switching
/// roles after a sign-out rebuilds the branch with the other screen rather than
/// leaving the previous audience's state behind it. [investor] is optional: on
/// the tabs where the investor's job is the same as the visitor's — the profile
/// — falling through is the correct answer, not a placeholder.
class _RoleScreen extends ConsumerWidget {
  const _RoleScreen({
    required this.visitor,
    required this.corporate,
    this.investor,
    this.entrepreneur,
  });

  final Widget visitor;
  final Widget corporate;
  final Widget? investor;
  final Widget? entrepreneur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(profileProvider).role) {
      UserRole.corporate => corporate,
      UserRole.investor => investor ?? visitor,
      UserRole.entrepreneur => entrepreneur ?? visitor,
      _ => visitor,
    };
  }
}

/// Shared route transition: a short fade with a slight lift.
///
/// Deliberately not a platform slide — a slide would push the aurora sideways
/// with the page and break the illusion that the background is one continuous
/// surface the screens float on.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
