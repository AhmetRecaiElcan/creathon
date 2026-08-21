import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/user_role.dart';

import '../../features/agenda/agenda_screen.dart';
import '../../features/expo/expo_screen.dart';
import '../../features/home/home_screen.dart';
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
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
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
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Picks between two screens by audience.
///
/// Both are built as constants and only one is mounted, so switching roles
/// after a sign-out rebuilds the branch with the other screen rather than
/// leaving the previous audience's state behind it.
class _RoleScreen extends ConsumerWidget {
  const _RoleScreen({required this.visitor, required this.corporate});

  final Widget visitor;
  final Widget corporate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(profileProvider).role == UserRole.corporate
        ? corporate
        : visitor;
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
