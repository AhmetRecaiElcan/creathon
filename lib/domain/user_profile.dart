import 'package:flutter/foundation.dart';

import 'investor_kind.dart';
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
    this.companyName = '',
    this.investorKind,
    this.wallpaper = ProfileWallpaper.aurora,
    this.photoBase64,
    this.sectors = const {},
    this.stages = const {},
    this.markets = const {},
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

  /// The fund or company the person represents.
  ///
  /// An investor is two things at once — a person a founder shakes hands with,
  /// and an institution whose name decides whether the meeting is worth taking
  /// — so both are collected, and the company travels with every request they
  /// send. Empty for the audiences that come as themselves.
  final String companyName;

  /// Angel or institutional. Null for every role but the investor.
  final InvestorKind? investorKind;

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

  /// Which maturity levels this account is looking for, from [Taxonomy.stages],
  /// and which market reaches, from [Taxonomy.markets].
  ///
  /// The investor's two extra filters. Empty means "no preference" rather than
  /// "nothing matches", so an account that never answered still sees every card
  /// — it just gets no ranking out of them.
  final Set<String> stages;
  final Set<String> markets;

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

  /// Everything the investor step asks for. A request that does not say which
  /// fund it came from, or what kind of money is behind it, arrives as an
  /// anonymous ask — which is the one thing this portfolio exists to avoid.
  bool get hasInvestorProfile =>
      companyName.trim().isNotEmpty && investorKind != null;

  /// How an investor introduces themselves in one line: `Ada Ventures ·
  /// Kurumsal`. Empty for the roles that carry neither.
  String get investorLine => [
    if (companyName.trim().isNotEmpty) companyName.trim(),
    if (investorKind != null) investorKind!.shortLabel,
  ].join('  ·  ');

  /// The name is entered before the account is created, so both halves being
  /// present is what makes the identity step complete.
  bool get hasIdentity =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      email.trim().isNotEmpty;

  /// Whether the tab shell may be entered. Interests are part of the bar
  /// because the home feed is built from them — landing on an empty feed would
  /// read as a broken app rather than as an unanswered question.
  bool get isOnboarded {
    if (role == null || !hasIdentity || !emailVerified) return false;
    if (sectors.isEmpty) return false;
    // The investor passes one extra gate: without the fund and the kind, the
    // requests this account exists to send could not identify themselves.
    if (role == UserRole.investor && !hasInvestorProfile) return false;
    return true;
  }

  UserProfile copyWith({
    UserRole? role,
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    bool? emailVerified,
    String? companyName,
    InvestorKind? investorKind,
    ProfileWallpaper? wallpaper,
    String? photoBase64,
    Set<String>? sectors,
    Set<String>? stages,
    Set<String>? markets,
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
      companyName: companyName ?? this.companyName,
      investorKind: investorKind ?? this.investorKind,
      wallpaper: wallpaper ?? this.wallpaper,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      sectors: sectors ?? this.sectors,
      stages: stages ?? this.stages,
      markets: markets ?? this.markets,
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
    'companyName': companyName,
    'investorKind': investorKind?.id,
    'wallpaper': wallpaper.id,
    'photoBase64': photoBase64,
    'sectors': sectors.toList(growable: false),
    'stages': stages.toList(growable: false),
    'markets': markets.toList(growable: false),
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
      companyName: (map['companyName'] as String?) ?? '',
      investorKind: InvestorKind.fromId(map['investorKind'] as String?),
      wallpaper: ProfileWallpaper.fromId(map['wallpaper'] as String?),
      photoBase64: map['photoBase64'] as String?,
      sectors: {...?(map['sectors'] as List?)?.whereType<String>()},
      stages: {...?(map['stages'] as List?)?.whereType<String>()},
      markets: {...?(map['markets'] as List?)?.whereType<String>()},
      savedEventIds: {
        ...?(map['savedEventIds'] as List?)?.whereType<String>(),
      },
      likedOrgIds: {
        ...?(map['likedOrgIds'] as List?)?.whereType<String>(),
      },
    );
  }
}
