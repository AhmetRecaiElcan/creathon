import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/organization_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/user_profile.dart';
import '../organization/organization_controller.dart';
import 'profile_controller.dart';

/// Brings back the account this device was already signed in as.
///
/// Firebase keeps the session on disk across restarts, so without this the app
/// would show the welcome screen to someone who never signed out — and worse,
/// picking a role again would start a second signup for an address that
/// already has an account.
///
/// Runs before the first frame and is deliberately forgiving: any failure
/// leaves the profile empty, which simply means the welcome screen appears.
Future<void> restoreSession(ProviderContainer container) async {
  final auth = container.read(authRepositoryProvider);
  final uid = auth.uid;
  if (!auth.hasSession || uid == null) return;

  // Refresh before reading, not after. The ID token cached on disk is the one
  // minted at signup, before the address was verified, and the security rules
  // check the token — so a read attempted first is refused, and the session
  // fails to restore for an account that is perfectly valid.
  var verified = false;
  try {
    verified = await auth.refreshVerification();
  } on AuthFailure catch (failure) {
    debugPrint('Doğrulama tazelenemedi: ${failure.message}');
    if (failure.sessionInvalid) {
      // The account behind this session is gone. Dropping it now is what lets
      // the welcome screen work: otherwise the device keeps a token nothing
      // will accept, and every read looks like a permissions problem.
      await auth.signOut();
      return;
    }
  } catch (error) {
    debugPrint('Doğrulama tazelenemedi: $error');
  }

  UserProfile? stored;
  try {
    stored = await container.read(profileRepositoryProvider).load(uid);
  } catch (error) {
    debugPrint('Oturum geri yüklenemedi: $error');
    return;
  }
  // No document means a signup that never reached the interests step; the
  // welcome screen and a fresh run through onboarding is the right answer.
  if (stored == null) return;

  // Offline, the flag stored with the profile is the best available truth: it
  // can only have been written after a successful verification.
  if (!verified && !stored.emailVerified) return;

  container
      .read(profileProvider.notifier)
      .hydrate(
        stored.copyWith(
          uid: uid,
          emailVerified: true,
          email: auth.email ?? stored.email,
        ),
      );

  // A card-publishing account — exhibitor or founder — is only half its record:
  // without the card the tab shell has nothing to show, and the router would
  // bounce them back into setup for something that is already published.
  if (stored.role?.publishesCard ?? false) {
    try {
      final organization = await container
          .read(organizationRepositoryProvider)
          .load(uid);
      if (organization != null) {
        container.read(organizationProvider.notifier).hydrate(organization);
      }
    } catch (error) {
      debugPrint('Kart geri yüklenemedi: $error');
    }
  }
}
