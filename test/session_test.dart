import 'package:creathon/data/auth_repository.dart';
import 'package:creathon/data/profile_repository.dart';
import 'package:creathon/domain/investor_kind.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:creathon/features/profile/profile_controller.dart';
import 'package:creathon/features/profile/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// Startup restore is what stops a returning visitor from being shown the
/// welcome screen — and, worse, from starting a second signup on an address
/// that already has an account. Every branch here decides whether the app
/// opens on the home tab or at the front door.
void main() {
  const complete = UserProfile(
    role: UserRole.visitor,
    uid: 'uid-1',
    firstName: 'Elif',
    lastName: 'Tunca',
    email: 'elif@example.com',
    emailVerified: true,
    sectors: {'Yapay Zekâ'},
  );

  Future<ProviderContainer> restore({
    required FakeAuthRepository auth,
    required FakeProfileStore profiles,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(container.dispose);
    await restoreSession(container);
    return container;
  }

  test('a verified account comes back complete', () async {
    final auth = FakeAuthRepository()..verified = true;
    await auth.signIn(email: 'elif@example.com', password: 'takeoff2026');

    final container = await restore(
      auth: auth,
      profiles: FakeProfileStore(complete),
    );

    final profile = container.read(profileProvider);
    expect(profile.isOnboarded, isTrue);
    expect(profile.firstName, 'Elif');
    expect(profile.sectors, {'Yapay Zekâ'});
  });

  test('an account from before the new filters still gets in', () async {
    // The investor's screening criteria were added after accounts existed. They
    // are collected at signup but must never gate entry: an account whose
    // document has no `stages` or `markets` has to open on the home tab, not be
    // pushed back through onboarding for answers it was never asked for.
    final auth = FakeAuthRepository()..verified = true;
    await auth.signIn(email: 'deniz@ada.vc', password: 'takeoff2026');

    final container = await restore(
      auth: auth,
      profiles: FakeProfileStore(
        const UserProfile(
          role: UserRole.investor,
          uid: 'uid-2',
          firstName: 'Deniz',
          lastName: 'Arslan',
          email: 'deniz@ada.vc',
          emailVerified: true,
          companyName: 'Ada Ventures',
          investorKind: InvestorKind.institutional,
          sectors: {'Yapay Zekâ'},
        ),
      ),
    );

    final profile = container.read(profileProvider);
    expect(profile.stages, isEmpty);
    expect(profile.markets, isEmpty);
    expect(
      profile.isOnboarded,
      isTrue,
      reason: 'a missing filter is "no preference", never a locked door',
    );
  });

  test('no session leaves the app at the welcome screen', () async {
    final container = await restore(
      auth: FakeAuthRepository(),
      profiles: FakeProfileStore(complete),
    );

    expect(container.read(profileProvider).role, isNull);
  });

  test('a session with no profile document is not restored', () async {
    final auth = FakeAuthRepository()..verified = true;
    await auth.signIn(email: 'elif@example.com', password: 'takeoff2026');

    final container = await restore(auth: auth, profiles: FakeProfileStore());

    expect(
      container.read(profileProvider).role,
      isNull,
      reason: 'a signup abandoned before the interests step must be redone',
    );
  });

  test('the token is refreshed before the profile is read', () async {
    // The account was verified in a browser after signup, so the token cached
    // on this device still says it was not. Firestore checks the token, which
    // is why reading the profile first fails and the session has to refresh
    // verification before it touches the database at all.
    final auth = FakeAuthRepository();
    await auth.signIn(email: 'elif@example.com', password: 'takeoff2026');
    auth
      ..verified = true
      ..tokenRefreshed = false;

    final container = await restore(
      auth: auth,
      profiles: FakeProfileStore(complete, auth),
    );

    expect(
      container.read(profileProvider).isOnboarded,
      isTrue,
      reason: 'a valid account must not be locked out by its own stale token',
    );
  });

  test('a session for a deleted account is dropped, not retried', () async {
    // Deleting the account in the console leaves the phone holding a token
    // nothing will accept. Keeping it makes every later read look like a
    // permissions bug, so the session has to go.
    final auth = FakeAuthRepository();
    await auth.signIn(email: 'elif@example.com', password: 'takeoff2026');
    // The account is removed from the console after this device signed in.
    auth.failure = const AuthFailure(
      'There is no user record corresponding to this identifier.',
      sessionInvalid: true,
    );

    final container = await restore(
      auth: auth,
      profiles: FakeProfileStore(complete),
    );

    expect(container.read(profileProvider).role, isNull);
    expect(auth.hasSession, isFalse, reason: 'the dead session must be cleared');
  });

  test('an unverified address is not let through', () async {
    final auth = FakeAuthRepository();
    await auth.signIn(email: 'elif@example.com', password: 'takeoff2026');

    final container = await restore(
      auth: auth,
      profiles: FakeProfileStore(
        complete.copyWith(emailVerified: false),
      ),
    );

    expect(container.read(profileProvider).role, isNull);
  });
}
