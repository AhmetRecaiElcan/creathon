import 'user_role.dart';

/// One address the organiser has admitted to the event, and the audience it was
/// admitted as.
///
/// The guest list is keyed by the address itself rather than by a generated id:
/// the only question ever asked of it is "is this e-mail allowed, and as what",
/// and a document id answers that in a single read with no query and no index.
class Invite {
  const Invite({
    required this.email,
    required this.role,
    this.note = '',
    this.createdAt,
  });

  /// The address as the organiser typed it. Kept for display only — [id] is
  /// what the collection is keyed by, and the two differ whenever the panel
  /// was given capitals.
  final String email;

  final UserRole? role;

  /// Free text the organiser can use to remember why this address is here
  /// ("jüri", "TÜBİTAK standı"). Never shown to the invitee.
  final String note;

  final DateTime? createdAt;

  /// The document id for an address.
  ///
  /// Lower-cased and trimmed, and this function is the *only* place that
  /// decision is made. The panel writing `Ahmet@x.com` while the phone looks
  /// up `ahmet@x.com` would refuse an invited guest at the door, which is the
  /// one failure this whole feature cannot afford — so both sides call here.
  static String idFor(String email) => email.trim().toLowerCase();

  String get id => idFor(email);

  Map<String, Object?> toMap() => {
    'email': email.trim(),
    'role': role?.id,
    'note': note.trim(),
    'createdAt': createdAt?.toIso8601String(),
  };

  static Invite fromMap(Map<String, Object?> map, {String? id}) => Invite(
    email: (map['email'] as String?) ?? id ?? '',
    role: UserRole.fromId(map['role'] as String?),
    note: (map['note'] as String?) ?? '',
    createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? ''),
  );
}

/// The answer to "is this address on the guest list".
///
/// Three cases, not two, and the third is the important one: a lookup that
/// could not be performed is *not* the same as an address that is absent. The
/// client-side check exists to produce a good error message, while the Firestore
/// rule on `users/{uid}` is what actually enforces admission — so when the read
/// fails, the app lets the attempt continue and the rule decides. Treating a
/// dropped connection as "not invited" would lock out the whole event the first
/// time the network hiccuped.
sealed class InviteLookup {
  const InviteLookup();
}

/// The guest list could not be read: Firebase is down, offline, or the rules
/// refused. Carries no verdict.
class InviteUnknown extends InviteLookup {
  const InviteUnknown();
}

/// The guest list was read and this address is not on it.
class InviteMissing extends InviteLookup {
  const InviteMissing();
}

/// The address is on the list, admitted as [role].
class InviteFound extends InviteLookup {
  const InviteFound(this.role);

  /// Null when the organiser saved a row without picking an audience. Treated
  /// as "any audience" rather than as a refusal — a half-filled row of the
  /// organiser's is not the guest's fault.
  final UserRole? role;
}
