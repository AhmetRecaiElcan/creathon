import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/invite.dart';

/// The guest list in `invites/{email}`.
///
/// Written by the admin panel alone. The app only ever asks about its own
/// address — the rules refuse a read of anyone else's row, so the collection
/// cannot be walked from a phone to find out who is coming.
abstract interface class InviteStore {
  /// Looks up one address. Never throws: a failure comes back as
  /// [InviteUnknown] so the caller can let the attempt through and leave the
  /// verdict to the Firestore rule.
  Future<InviteLookup> find(String email);
}

class FirestoreInviteStore implements InviteStore {
  const FirestoreInviteStore();

  static const collection = 'invites';

  @override
  Future<InviteLookup> find(String email) async {
    // No backend this run — widget tests and a failed boot both land here, and
    // neither can be allowed to refuse a signup the rules would have accepted.
    if (!firebaseReady) return const InviteUnknown();

    final id = Invite.idFor(email);
    if (id.isEmpty) return const InviteUnknown();

    try {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(id)
          .get();
      if (!doc.exists) return const InviteMissing();
      return InviteFound(Invite.fromMap(doc.data() ?? const {}, id: id).role);
    } catch (error) {
      // Includes permission-denied, which happens when the rules have not been
      // published yet. Reporting "you are not invited" then would be a lie
      // about the guest and the truth about the deployment.
      debugPrint('Davet listesi okunamadı: $error');
      return const InviteUnknown();
    }
  }
}

/// Stand-in for the flows that run with no backend, and the seam tests override.
class OpenInviteStore implements InviteStore {
  const OpenInviteStore();

  @override
  Future<InviteLookup> find(String email) async => const InviteUnknown();
}

final inviteStoreProvider = Provider<InviteStore>(
  (ref) => const FirestoreInviteStore(),
);
