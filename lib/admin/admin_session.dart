import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Who is holding the panel open.
enum AdminStatus {
  /// Nobody is signed in.
  signedOut,

  /// Signed in, but this account is not in `admins`. Kept distinct from
  /// [signedOut] because the two need opposite screens: one asks for
  /// credentials, the other says the credentials were fine and the account
  /// still is not allowed.
  notAdmin,

  /// Signed in and listed. The panel opens.
  admin,
}

class AdminSession {
  const AdminSession({required this.status, this.email});

  final AdminStatus status;
  final String? email;

  static const unknown = AdminSession(status: AdminStatus.signedOut);
}

/// Follows the Firebase session and checks it against `admins/{uid}` on every
/// change.
///
/// The membership read has to be redone per sign-in rather than cached at
/// startup: the panel is a long-lived browser tab, and an operator signing out
/// and back in as somebody else must not inherit the first account's answer.
final adminSessionProvider = StreamProvider<AdminSession>((ref) {
  final auth = FirebaseAuth.instance;
  return auth.authStateChanges().asyncMap((user) async {
    if (user == null) return AdminSession.unknown;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      return AdminSession(
        status: doc.exists ? AdminStatus.admin : AdminStatus.notAdmin,
        email: user.email,
      );
    } catch (_) {
      // A refused or failed read is not an admission. The panel writes to the
      // guest list, so "could not confirm" has to mean "not allowed" here —
      // the opposite of the invite lookup on the phone, where a failed read
      // must not lock a guest out and the rules still have the last word.
      return AdminSession(status: AdminStatus.notAdmin, email: user.email);
    }
  });
});

/// Sign-in for the panel. Reuses the app's [AuthFailure] wording so the operator
/// sees the same Turkish messages the phone shows.
class AdminAuth {
  const AdminAuth(this._auth);

  final FirebaseAuth _auth;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(switch (error.code) {
        'invalid-email' => 'Geçerli bir e-posta adresi gir.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'E-posta veya şifre hatalı.',
        'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
        'too-many-requests' =>
          'Çok fazla deneme yapıldı, biraz sonra tekrar dene.',
        'network-request-failed' => 'İnternet bağlantısı kurulamadı.',
        _ => error.message ?? 'Giriş yapılamadı.',
      });
    }
  }

  Future<void> signOut() => _auth.signOut();
}

final adminAuthProvider = Provider(
  (ref) => AdminAuth(FirebaseAuth.instance),
);
