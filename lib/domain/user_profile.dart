import 'package:flutter/foundation.dart';

import 'profile_wallpaper.dart';
import 'user_role.dart';

/// Everything the app knows about the person using it, in one immutable value.
///
/// This replaces the old onboarding draft: identity, interests and appearance
/// are the same record now, so what onboarding collects and what the profile
/// screen edits can never drift apart.
@immutable
class UserProfile {
  const UserProfile({
    this.role,
    this.uid,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.emailVerified = false,
    this.wallpaper = ProfileWallpaper.aurora,
    this.photoBase64,
    this.sectors = const {},
    this.savedEventIds = const {},
    this.likedOrgIds = const {},
  });

  /// Which of the four audiences this person joined as. Null until picked.
  final UserRole? role;

  /// Firebase Auth uid, once the account exists.
  final String? uid;

  final String firstName;
  final String lastName;
  final String email;

  /// Mirrors `FirebaseUser.emailVerified` at the last refresh.
  final bool emailVerified;

  final ProfileWallpaper wallpaper;

  /// Avatar, held inline as a base64 JPEG rather than as a Storage URL.
  ///
  /// The picker already downsizes to 512px at quality 80, which lands well
  /// under Firestore's 1 MiB document limit — and keeping it in the user's own
  /// document means no Storage bucket, no bucket rules, and no second request
  /// to render a profile the app has already loaded.
  final String? photoBase64;

  /// Interests from [Taxonomy.sectors]; what the programme is filtered against.
  final Set<String> sectors;

  /// Ids of the sessions the user added to their own agenda from the home
  /// feed. Kept on the profile rather than in a separate store so one write
  /// keeps the whole account in sync.
  final Set<String> savedEventIds;

  /// Exhibitors whose info card the user kept after scanning it. They join the
  /// sessions on the agenda, because "which stands am I going back to" is the
  /// same question as "what am I doing today".
  final Set<String> likedOrgIds;

  String get fullName => '$firstName $lastName'.trim();

  /// Up to two letters for the avatar. Falls back to the email so a profile
  /// mid-signup still shows something recognisable.
  String get initials {
    final parts = [
      firstName,
      lastName,
    ].where((p) => p.trim().isNotEmpty).toList(growable: false);
    if (parts.isEmpty) {
      return email.isEmpty ? '?' : email.substring(0, 1).toUpperCase();
    }
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// The name is entered before the account is created, so both halves being
  /// present is what makes the identity step complete.
  bool get hasIdentity =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      email.trim().isNotEmpty;

  /// Whether the tab shell may be entered. Interests are part of the bar
  /// because the home feed is built from them — landing on an empty feed would
  /// read as a broken app rather than as an unanswered question.
  bool get isOnboarded =>
      role != null && hasIdentity && emailVerified && sectors.isNotEmpty;

  UserProfile copyWith({
    UserRole? role,
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    bool? emailVerified,
    ProfileWallpaper? wallpaper,
    String? photoBase64,
    Set<String>? sectors,
    Set<String>? savedEventIds,
    Set<String>? likedOrgIds,
    // Removing the avatar cannot be expressed by passing null, which means
    // "leave it alone" everywhere else in this method.
    bool clearPhoto = false,
  }) {
    return UserProfile(
      role: role ?? this.role,
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      wallpaper: wallpaper ?? this.wallpaper,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      sectors: sectors ?? this.sectors,
      savedEventIds: savedEventIds ?? this.savedEventIds,
      likedOrgIds: likedOrgIds ?? this.likedOrgIds,
    );
  }

  /// Shape written to `users/{uid}` in Firestore.
  Map<String, Object?> toMap() => {
    'role': role?.id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'emailVerified': emailVerified,
    'wallpaper': wallpaper.id,
    'photoBase64': photoBase64,
    'sectors': sectors.toList(growable: false),
    'savedEventIds': savedEventIds.toList(growable: false),
    'likedOrgIds': likedOrgIds.toList(growable: false),
  };

  static UserProfile fromMap(Map<String, Object?> map, {String? uid}) {
    return UserProfile(
      role: UserRole.fromId(map['role'] as String?),
      uid: uid,
      firstName: (map['firstName'] as String?) ?? '',
      lastName: (map['lastName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      emailVerified: (map['emailVerified'] as bool?) ?? false,
      wallpaper: ProfileWallpaper.fromId(map['wallpaper'] as String?),
      photoBase64: map['photoBase64'] as String?,
      sectors: {...?(map['sectors'] as List?)?.whereType<String>()},
      savedEventIds: {
        ...?(map['savedEventIds'] as List?)?.whereType<String>(),
      },
      likedOrgIds: {
        ...?(map['likedOrgIds'] as List?)?.whereType<String>(),
      },
    );
  }
}
