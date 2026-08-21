import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/user_profile.dart';

/// The user's own record in `users/{uid}`.
///
/// Writes are fire-and-forget from the UI's point of view: the app already
/// holds the profile in memory, so a failed sync must never block editing a
/// sector or swapping a wallpaper.
abstract final class ProfileRepository {
  static const collection = 'users';

  static Future<void> save(UserProfile profile) async {
    final uid = profile.uid;
    if (!firebaseReady || uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (error) {
      debugPrint('Profil kaydedilemedi: $error');
    }
  }

  static Future<void> delete(String uid) async {
    if (!firebaseReady) return;
    try {
      await FirebaseFirestore.instance.collection(collection).doc(uid).delete();
    } catch (error) {
      debugPrint('Profil silinemedi: $error');
    }
  }

  static Future<UserProfile?> load(String uid) async {
    if (!firebaseReady) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null) return null;
      return UserProfile.fromMap(data, uid: uid);
    } catch (error) {
      debugPrint('Profil okunamadı: $error');
      return null;
    }
  }
}

/// Indirection so tests can drive the profile round trip without standing up
/// Firestore.
final profileRepositoryProvider = Provider<ProfileStore>(
  (ref) => const FirestoreProfileStore(),
);

abstract interface class ProfileStore {
  Future<void> save(UserProfile profile);

  /// Removes the account's own document. Part of deleting an account, which
  /// the app has to do itself — a console deletion reaches Auth only.
  Future<void> delete(String uid);

  /// Returns null when the account has no document yet — a signup that was
  /// abandoned before the interests step, which the caller resumes rather
  /// than treating as an error.
  Future<UserProfile?> load(String uid);
}

class FirestoreProfileStore implements ProfileStore {
  const FirestoreProfileStore();

  @override
  Future<void> save(UserProfile profile) => ProfileRepository.save(profile);

  @override
  Future<UserProfile?> load(String uid) => ProfileRepository.load(uid);

  @override
  Future<void> delete(String uid) => ProfileRepository.delete(uid);
}
