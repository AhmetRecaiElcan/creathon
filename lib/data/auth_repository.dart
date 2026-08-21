import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';

/// A failure worth showing the user, already phrased in Turkish.
///
/// Firebase codes are surfaced this way rather than raw because onboarding is
/// the one place a stranger meets the app: "invalid-email" is noise, "Geçerli
/// bir e-posta adresi gir" is an instruction.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.sessionInvalid = false});

  final String message;

  /// The session on this device points at an account the server will not
  /// accept any more — deleted, disabled, or with credentials revoked.
  ///
  /// Flagged rather than string-matched so the caller can clear the dead
  /// session instead of retrying against it forever.
  final bool sessionInvalid;

  @override
  String toString() => message;
}

/// Account creation plus e-mail verification, which is all the visitor flow
/// needs from an identity provider.
abstract interface class AuthRepository {
  /// The address the current account was opened with, if any.
  String? get email;

  String? get uid;

  /// Whether a session from an earlier run is still open on this device.
  bool get hasSession;

  /// Creates the account — or signs back into it if this address already has
  /// one — and sends the verification mail.
  Future<void> registerAndSendVerification({
    required String email,
    required String password,
  });

  /// Signs an existing account in. Used by the returning visitor, who must not
  /// be asked to invent their name and password again.
  Future<void> signIn({required String email, required String password});

  /// Re-reads the account from the server and reports whether the link in the
  /// mail has been followed yet.
  Future<bool> refreshVerification();

  Future<void> resendVerification();

  Future<void> signOut();

  /// Removes the account itself.
  ///
  /// Deleting a user from the Firebase console cannot reach into Firestore —
  /// there is no hook a client can see — so the app has to own the whole
  /// teardown: the caller clears the documents first, then this drops the
  /// account that owned them.
  Future<void> deleteAccount();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  bool get hasSession => _auth.currentUser != null;

  @override
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
      throw AuthFailure(_signInMessageFor(error));
    }
  }

  @override
  Future<void> registerAndSendVerification({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      // Coming back to finish a signup that was abandoned before the mail was
      // opened is the normal case, not an error — sign in and carry on.
      if (error.code == 'email-already-in-use') {
        try {
          await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } on FirebaseAuthException catch (signInError) {
          throw AuthFailure(_messageFor(signInError));
        }
      } else {
        throw AuthFailure(_messageFor(error));
      }
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Hesap oluşturuldu ama oturum açılamadı.');
    }
    if (!user.emailVerified) {
      await _send(user);
    }
  }

  @override
  Future<bool> refreshVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      // reload() refreshes the cached record; the flag on the old instance
      // never changes on its own, so currentUser has to be read again after.
      await user.reload();
      // reload() replaces the cached record, so the refreshed instance — not
      // the one captured above — is the one to ask.
      final refreshed = _auth.currentUser;
      final verified = refreshed?.emailVerified ?? false;

      if (verified && refreshed != null) {
        // The ID token carries `email_verified` as a claim, and reload() does
        // not reissue it. Firestore rules read the token, not the local user
        // object, so without forcing a refresh here the first write after
        // verification is rejected with permission-denied — while the app is
        // convinced the address is verified.
        await refreshed.getIdToken(true);
      }
      return verified;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(
        _messageFor(error),
        sessionInvalid: _isDeadSession(error.code),
      );
    }
  }

  /// Codes that mean "stop trusting the session on this device".
  ///
  /// An account deleted from the console leaves the phone holding a token for
  /// a user that no longer exists; every request then fails in a way that
  /// looks like a permissions bug until the session is dropped.
  static bool _isDeadSession(String code) => const {
    'user-not-found',
    'user-disabled',
    'user-token-expired',
    'invalid-user-token',
    'requires-recent-login',
  }.contains(code);

  @override
  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Önce e-posta adresini kaydetmen gerekiyor.');
    }
    await _send(user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      // Firebase refuses to delete an account whose sign-in is old, and the
      // only remedy is a fresh sign-in — which the user has to do, so say so.
      if (error.code == 'requires-recent-login') {
        throw const AuthFailure(
          'Güvenlik için önce çıkıp tekrar giriş yapman gerekiyor.',
        );
      }
      throw AuthFailure(_messageFor(error));
    }
  }

  Future<void> _send(User user) async {
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    }
  }

  /// Sign-in needs its own wording: on this path "no such account" and "wrong
  /// password" are the likely mistakes, and Firebase reports both as
  /// `invalid-credential` so the message must cover the pair honestly.
  static String _signInMessageFor(FirebaseAuthException error) =>
      switch (error.code) {
        'invalid-email' => 'Geçerli bir e-posta adresi gir.',
        'user-not-found' =>
          'Bu adresle bir hesap yok. Aşağıdan kayıt olabilirsin.',
        'wrong-password' ||
        'invalid-credential' =>
          'E-posta veya şifre hatalı.',
        _ => _messageFor(error),
      };

  static String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'invalid-email' => 'Geçerli bir e-posta adresi gir.',
    'weak-password' => 'Şifre en az 6 karakter olmalı.',
    'wrong-password' ||
    'invalid-credential' =>
      'Bu e-posta zaten kayıtlı ve şifre eşleşmiyor.',
    'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
    'too-many-requests' => 'Çok fazla deneme yapıldı, biraz sonra tekrar dene.',
    'network-request-failed' => 'İnternet bağlantısı kurulamadı.',
    'operation-not-allowed' =>
      'E-posta ile giriş Firebase konsolunda açık değil.',
    _ => error.message ?? 'Beklenmeyen bir hata oluştu.',
  };
}

/// Stand-in used when Firebase never came up.
///
/// It refuses loudly instead of pretending to succeed: silently reporting a
/// verified address the backend has never seen would let an unverified user
/// walk straight into the app.
class OfflineAuthRepository implements AuthRepository {
  const OfflineAuthRepository();

  static const _unavailable = AuthFailure(
    'Firebase bağlantısı kurulamadı. İnternetini kontrol edip tekrar dene.',
  );

  @override
  String? get email => null;

  @override
  String? get uid => null;

  @override
  bool get hasSession => false;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => throw _unavailable;

  @override
  Future<void> registerAndSendVerification({
    required String email,
    required String password,
  }) async => throw _unavailable;

  @override
  Future<bool> refreshVerification() async => throw _unavailable;

  @override
  Future<void> resendVerification() async => throw _unavailable;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async => throw _unavailable;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!firebaseReady) return const OfflineAuthRepository();
  return FirebaseAuthRepository(FirebaseAuth.instance);
});
