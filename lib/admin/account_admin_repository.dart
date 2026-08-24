import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

/// What the teardown actually removed, reported back so the operator can check
/// it rather than take "silindi" on faith.
class AccountTeardown {
  const AccountTeardown({
    required this.meetings,
    required this.feedback,
    required this.stands,
    required this.hadCard,
    required this.authDeleted,
  });

  final int meetings;
  final int feedback;
  final int stands;
  final bool hadCard;

  /// False when Auth had no such user — the account had already been deleted
  /// from the console and what this cleared was the wreckage it left behind.
  final bool authDeleted;

  String get summary => [
    if (authDeleted) 'hesap silindi' else 'Auth kaydı zaten yoktu',
    if (hadCard) 'kart kaldırıldı',
    if (stands > 0) 'stant serbest bırakıldı',
    if (meetings > 0) '$meetings görüşme iptal edildi',
    if (feedback > 0) '$feedback değerlendirme silindi',
  ].join(', ');
}

class AccountFailure implements Exception {
  const AccountFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Registered accounts, from the organiser's side.
class AccountAdminRepository {
  const AccountAdminRepository();

  /// Must match `REGION` in `functions/index.js`; a callable invoked against
  /// the wrong region fails as "not found", which reads like a missing
  /// deployment rather than a wrong address.
  static const region = 'europe-west1';

  /// Every account that finished signing up.
  ///
  /// Read from `users` rather than from Auth because the panel has no admin
  /// SDK — and because a profile document is the better list anyway: an Auth
  /// account with no profile is an abandoned signup, not a participant.
  Stream<List<UserProfile>> watch() => FirebaseFirestore.instance
      .collection(ProfileRepository.collection)
      .snapshots()
      .map((snap) {
        final accounts = snap.docs
            .map((doc) => UserProfile.fromMap(doc.data(), uid: doc.id))
            .toList();
        accounts.sort((a, b) => a.email.compareTo(b.email));
        return accounts;
      });

  /// Which accounts have a published card, so a row can warn that deleting it
  /// also takes a stand off the floor plan.
  Stream<Set<String>> watchCardHolders() => FirebaseFirestore.instance
      .collection('organizations')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.id).toSet());

  /// Removes the account and everything keyed to it.
  ///
  /// Goes through a Cloud Function because none of this is reachable from a
  /// browser: deleting an Auth user needs the admin SDK, and the meeting rules
  /// let only the two parties touch a request — so a meeting belonging to the
  /// account being deleted could not be cleared by the panel at all.
  Future<AccountTeardown> delete(String uid) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: region,
      ).httpsCallable('adminDeleteAccount');
      final result = await callable.call<Map<Object?, Object?>>({'uid': uid});
      final data = result.data;
      return AccountTeardown(
        meetings: (data['meetings'] as num?)?.toInt() ?? 0,
        feedback: (data['feedback'] as num?)?.toInt() ?? 0,
        stands: (data['stands'] as num?)?.toInt() ?? 0,
        hadCard: data['hadCard'] == true,
        authDeleted: data['authDeleted'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      // The function's own refusals already say something useful in Turkish —
      // "this account is an admin", "you cannot delete your own" — so they are
      // passed through rather than flattened into one apology.
      debugPrint('Hesap silinemedi: ${error.code} ${error.message}');
      throw AccountFailure(
        error.message?.isNotEmpty == true
            ? error.message!
            : 'Hesap silinemedi. Tekrar dene.',
      );
    } catch (error) {
      debugPrint('Hesap silinemedi: $error');
      throw const AccountFailure(
        'Hesap silinemedi. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final accountAdminRepositoryProvider = Provider(
  (ref) => const AccountAdminRepository(),
);

final accountsProvider = StreamProvider<List<UserProfile>>(
  (ref) => ref.watch(accountAdminRepositoryProvider).watch(),
);

final cardHoldersProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(accountAdminRepositoryProvider).watchCardHolders(),
);
