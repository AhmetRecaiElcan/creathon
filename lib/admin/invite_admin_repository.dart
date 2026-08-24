import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/invite_repository.dart';
import '../domain/invite.dart';
import '../domain/user_role.dart';

/// Raised when the panel refuses a row rather than when Firestore does, so the
/// form can say why in Turkish instead of surfacing a rules error.
class InviteFailure implements Exception {
  const InviteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The guest list, from the organiser's side.
class InviteAdminRepository {
  const InviteAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _invites =>
      _db.collection(FirestoreInviteStore.collection);

  /// Newest first: the row just typed is the one being looked for.
  Stream<List<Invite>> watch() => _invites
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => Invite.fromMap(doc.data(), id: doc.id))
            .toList(),
      );

  /// Adds an address to the list.
  ///
  /// Refuses to overwrite an existing row: silently changing the audience of an
  /// address that has already registered would leave a signed-up account whose
  /// role no longer matches its own profile document, and the freeze on the
  /// role field means nothing could then repair it. Removing the row first is
  /// the deliberate act that says the operator means it.
  Future<void> add({
    required String email,
    required UserRole role,
    String note = '',
  }) async {
    final id = Invite.idFor(email);
    if (id.isEmpty) throw const InviteFailure('E-posta adresi gir.');
    if (!_emailPattern.hasMatch(id)) {
      throw const InviteFailure('Geçerli bir e-posta adresi gir.');
    }

    final doc = _invites.doc(id);
    if ((await doc.get()).exists) {
      throw const InviteFailure(
        'Bu adres listede zaten var. Rolünü değiştirmek için önce sil.',
      );
    }

    await doc.set(
      Invite(
        email: id,
        role: role,
        note: note,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  /// Removes an address.
  ///
  /// Only closes the door on *future* signups: an account that already
  /// registered keeps working, because its profile document exists and the
  /// guest list is checked at creation alone. Taking an account away is a
  /// separate job with its own teardown — the meetings, the card and the booth
  /// all have to go with it — and this button is not it.
  Future<void> remove(String id) => _invites.doc(id).delete();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
}

final inviteAdminRepositoryProvider = Provider(
  (ref) => InviteAdminRepository(FirebaseFirestore.instance),
);

final invitesProvider = StreamProvider<List<Invite>>(
  (ref) => ref.watch(inviteAdminRepositoryProvider).watch(),
);

/// Addresses that have finished signing up, so a row can show whether its guest
/// actually arrived.
///
/// Read from `users` rather than from Auth: the panel has no admin SDK, and a
/// profile document is the better signal anyway — an Auth account with no
/// profile is a signup that was abandoned, which is exactly what the operator
/// wants to be able to see.
final registeredEmailsProvider = StreamProvider<Set<String>>(
  (ref) => FirebaseFirestore.instance.collection('users').snapshots().map(
    (snap) => snap.docs
        .map((doc) => Invite.idFor((doc.data()['email'] as String?) ?? ''))
        .where((email) => email.isNotEmpty)
        .toSet(),
  ),
);
