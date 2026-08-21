import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../domain/organization.dart';

/// Raised when a booth was claimed by someone else between the moment it was
/// offered and the moment it was confirmed.
class StandTakenFailure implements Exception {
  const StandTakenFailure(this.code);

  final String code;

  @override
  String toString() =>
      '$code standı bu arada başka bir kurum tarafından alındı.';
}

/// The write was refused for a reason that is not a booth clash.
///
/// Kept separate because the two demand opposite responses: a taken booth means
/// "pick another one", a refused write means the backend is not configured to
/// accept this account yet, and telling an exhibitor their booth was stolen
/// when it was not sends them chasing the wrong problem.
class PublishFailure implements Exception {
  const PublishFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exhibitors, and the booth reservations that keep the floor plan honest.
///
/// Two collections, on purpose:
/// * `organizations/{uid}` — the full card, owned and editable by the company.
/// * `stands/{code}` — a create-only lock holding just `{ orgId }`.
///
/// Firestore rejects a `create` on a document that already exists, so the lock
/// is what makes "first to confirm wins" true. Security rules can compare
/// fields within one document but cannot check uniqueness across a collection,
/// so uniqueness has to be expressed as a document id — which is exactly what
/// the booth code is.
abstract interface class OrganizationRepository {
  static const organizations = 'organizations';
  static const stands = 'stands';

  Stream<List<Organization>> watchAll();

  Future<Organization?> load(String id);

  /// Reserves [code] for [organization] and writes the card in one batch, so a
  /// published card can never point at a booth the company does not hold.
  ///
  /// Throws [StandTakenFailure] when the booth is already reserved.
  Future<void> publish(Organization organization);

  /// Updates an already published card. The booth is not part of this — it is
  /// fixed at publish time.
  Future<void> update(Organization organization);

  /// Removes the card and releases the booth lock in one batch, so the floor
  /// plan can never show a stand belonging to a card that no longer exists.
  Future<void> withdraw(Organization organization);
}

class FirestoreOrganizationRepository implements OrganizationRepository {
  const FirestoreOrganizationRepository();

  @override
  Stream<List<Organization>> watchAll() {
    if (!firebaseReady) return Stream.value(const <Organization>[]);
    return FirebaseFirestore.instance
        .collection(OrganizationRepository.organizations)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Organization.fromMap(doc.data(), id: doc.id))
              .toList(growable: false),
        );
  }

  @override
  Future<Organization?> load(String id) async {
    if (!firebaseReady) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(OrganizationRepository.organizations)
          .doc(id)
          .get();
      final data = doc.data();
      return data == null ? null : Organization.fromMap(data, id: doc.id);
    } catch (error) {
      debugPrint('Kurum okunamadı: $error');
      return null;
    }
  }

  @override
  Future<void> publish(Organization organization) async {
    final code = organization.standCode;
    if (code == null) {
      throw StateError('Yayına almadan önce bir stand seçilmeli.');
    }
    if (!firebaseReady) {
      throw const PublishFailure(
        'Firebase bağlantısı kurulamadı. İnternetini kontrol edip tekrar dene.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.set(
      firestore.collection(OrganizationRepository.stands).doc(code),
      {'orgId': organization.id},
      // No merge: this must be a create so that an existing reservation makes
      // the whole batch fail rather than quietly overwriting another company.
    );
    batch.set(
      firestore
          .collection(OrganizationRepository.organizations)
          .doc(organization.id),
      organization.toMap(),
      SetOptions(merge: true),
    );

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists') throw StandTakenFailure(code);
      if (error.code != 'permission-denied') {
        throw PublishFailure('Kart yayına alınamadı: ${error.message}');
      }

      // permission-denied is ambiguous. The rules allow only `create` on a
      // lock, so claiming a booth someone already holds is refused with the
      // same code as a project whose rules were never published — and the two
      // need opposite advice. Asking whether the lock exists settles it.
      throw await _explain(code);
    }
  }

  /// Turns a refused publish into the specific complaint it actually is.
  Future<Exception> _explain(String code) async {
    try {
      final lock = await FirebaseFirestore.instance
          .collection(OrganizationRepository.stands)
          .doc(code)
          .get();
      if (lock.exists) return StandTakenFailure(code);
    } catch (_) {
      // Even reading the lock was refused, which points at the rules rather
      // than at the booth.
    }
    return const PublishFailure(
      'Firestore bu yazmayı reddetti. Güncel güvenlik kurallarının yayında '
      'olduğunu ve e-posta adresinin doğrulandığını kontrol et.',
    );
  }

  @override
  Future<void> update(Organization organization) async {
    if (!firebaseReady) return;
    try {
      await FirebaseFirestore.instance
          .collection(OrganizationRepository.organizations)
          .doc(organization.id)
          .set(organization.toMap(), SetOptions(merge: true));
    } catch (error) {
      debugPrint('Kurum kaydedilemedi: $error');
    }
  }

  @override
  Future<void> withdraw(Organization organization) async {
    if (!firebaseReady) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.delete(
      firestore
          .collection(OrganizationRepository.organizations)
          .doc(organization.id),
    );

    final code = organization.standCode;
    if (code != null) {
      batch.delete(
        firestore.collection(OrganizationRepository.stands).doc(code),
      );
    }

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw PublishFailure('Kart silinemedi: ${error.message}');
    }
  }
}

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => const FirestoreOrganizationRepository(),
);

/// Every exhibitor. The collection is one document per company at one event, so
/// it is small enough to hold whole — which lets the fair hall, the scanner and
/// the liked list all read from the same live list.
final organizationsStreamProvider = StreamProvider<List<Organization>>(
  (ref) => ref.watch(organizationRepositoryProvider).watchAll(),
);

final organizationsProvider = Provider<List<Organization>>(
  (ref) => ref.watch(organizationsStreamProvider).value ?? const [],
);

/// Exhibitors indexed by the booth they stand on.
final organizationsByStandProvider = Provider<Map<String, Organization>>((ref) {
  final byStand = <String, Organization>{};
  for (final organization in ref.watch(organizationsProvider)) {
    final code = organization.standCode;
    if (code != null) byStand[code] = organization;
  }
  return byStand;
});

final organizationByIdProvider = Provider.family<Organization?, String>((
  ref,
  id,
) {
  for (final organization in ref.watch(organizationsProvider)) {
    if (organization.id == id) return organization;
  }
  return null;
});
