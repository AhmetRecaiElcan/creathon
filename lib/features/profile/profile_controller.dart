import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../data/profile_repository.dart';
import '../../domain/investor_kind.dart';
import '../../domain/profile_wallpaper.dart';
import '../../domain/user_profile.dart';
import '../../domain/user_role.dart';

/// Single source of truth for who the user is.
///
/// Every mutation mirrors the new value to Firestore, so the profile screen and
/// the signup flow stay one record instead of two that have to be reconciled.
class ProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() => const UserProfile();

  /// Switching audience clears the rest: the questions and the valid answers
  /// differ per role, so carrying selections over would keep answers the new
  /// role was never offered.
  ///
  /// An account that already exists is the exception — a returning visitor who
  /// re-picks their role must not have their restored name and interests wiped
  /// just for tapping the card again.
  void selectRole(UserRole role) {
    if (state.role == role) return;
    state = state.uid == null
        ? UserProfile(role: role)
        : state.copyWith(role: role);
  }

  /// Replaces the local profile with the one stored for this account.
  ///
  /// Used both when a returning visitor signs in and when a session from an
  /// earlier run is restored at startup.
  void hydrate(UserProfile remote) => state = remote;

  void setIdentity({
    required String firstName,
    required String lastName,
    required String email,
  }) {
    state = state.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim(),
    );
    _sync();
  }

  /// The investor's own two answers: who they invest for, and with what kind of
  /// money.
  ///
  /// One method for both because signup collects them together — a fund with no
  /// kind, or a kind with no fund, is not an introduction — while the profile
  /// screen changes one at a time. Omitting a field leaves it alone.
  void setInvestorProfile({String? companyName, InvestorKind? investorKind}) {
    if (companyName == null && investorKind == null) return;
    state = state.copyWith(
      companyName: companyName?.trim(),
      investorKind: investorKind,
    );
    _sync();
  }

  void markVerified({String? uid}) {
    state = state.copyWith(emailVerified: true, uid: uid);
    _sync();
  }

  /// Replaces the interest set outright.
  ///
  /// For the flow where another answer already implies it: a founder's venture
  /// field is the same question as "which areas interest you", and asking twice
  /// is how a signup loses people.
  void setSectors(Set<String> sectors) {
    state = state.copyWith(sectors: sectors);
    _sync();
  }

  void toggleSector(String sector) {
    final next = Set<String>.of(state.sectors);
    if (!next.remove(sector)) next.add(sector);
    state = state.copyWith(sectors: next);
    _sync();
  }

  /// Adds or removes a session from the user's own agenda. This is the one
  /// action the home feed offers, so it has to be idempotent per session id.
  void toggleSavedEvent(String eventId) {
    final next = Set<String>.of(state.savedEventIds);
    if (!next.remove(eventId)) next.add(eventId);
    state = state.copyWith(savedEventIds: next);
    _sync();
  }

  /// Keeps or drops an exhibitor's info card after a scan.
  void toggleLikedOrg(String organizationId) {
    final next = Set<String>.of(state.likedOrgIds);
    if (!next.remove(organizationId)) next.add(organizationId);
    state = state.copyWith(likedOrgIds: next);
    _sync();
  }

  void setWallpaper(ProfileWallpaper wallpaper) {
    state = state.copyWith(wallpaper: wallpaper);
    _sync();
  }

  void setPhoto(String base64Jpeg) {
    state = state.copyWith(photoBase64: base64Jpeg);
    _sync();
  }

  void clearPhoto() {
    state = state.copyWith(clearPhoto: true);
    _sync();
  }

  void reset() => state = const UserProfile();

  void _sync() {
    if (state.uid == null) return;
    ref.read(profileRepositoryProvider).save(state);
  }
}

final profileProvider = NotifierProvider<ProfileController, UserProfile>(
  ProfileController.new,
);

/// Accent for the whole app. Before a role is picked this is the neutral brand
/// indigo; afterwards the app takes on that audience's colour.
final accentProvider = Provider<Color>(
  (ref) => ref.watch(profileProvider).role?.accent ?? AppPalette.brand,
);

/// Blob palette handed to the aurora background.
final auroraPaletteProvider = Provider<List<Color>>((ref) {
  final role = ref.watch(profileProvider).role;
  return role?.auroraPalette ?? UserRole.neutralAuroraPalette;
});
