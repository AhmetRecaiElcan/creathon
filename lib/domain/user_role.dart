import 'package:flutter/material.dart';

/// The four audiences the brief requires. Each one carries its own accent so
/// the whole app re-themes the moment a role is chosen — the visual promise
/// that this is one platform serving four different goals.
enum UserRole {
  entrepreneur(
    id: 'entrepreneur',
    label: 'Girişimci',
    shortGoal: 'Yatırımcı ve kurumlarla eşleş',
    goal: 'Doğru yatırımcı ve kurumları bul, bağlantıyı görüşmeye dönüştür.',
    accent: Color(0xFFFF9F1C),
    icon: Icons.rocket_launch_rounded,
  ),
  investor(
    id: 'investor',
    label: 'Yatırımcı',
    shortGoal: 'Tezine uyan girişimleri keşfet',
    goal: 'Yatırım tezine uyan girişimleri hızla keşfet ve önceliklendir.',
    accent: Color(0xFF2FD98A),
    icon: Icons.trending_up_rounded,
  ),
  corporate(
    id: 'corporate',
    label: 'Kurum / Partner',
    shortGoal: 'Pilot ve iş birliği fırsatı bul',
    goal: 'Teknoloji ihtiyacına uygun girişimlerle pilot ve iş birliği kur.',
    accent: Color(0xFF3B9BFF),
    icon: Icons.apartment_rounded,
  ),
  visitor(
    id: 'visitor',
    label: 'Ziyaretçi',
    shortGoal: 'Programını kur, alanda yön bul',
    goal: 'İlgi alanına göre programını kur, etkinlik alanında yönünü bul.',
    accent: Color(0xFFA97BFF),
    icon: Icons.explore_rounded,
  );

  const UserRole({
    required this.id,
    required this.label,
    required this.shortGoal,
    required this.goal,
    required this.accent,
    required this.icon,
  });

  /// Stable key for Firestore documents and analytics; never localise this.
  final String id;

  /// Turkish display name shown in the UI.
  final String label;

  /// Card-sized promise. Kept short so it wraps to two lines in a grid tile.
  final String shortGoal;

  /// The full outcome this role came to Take Off for, straight from the brief.
  final String goal;

  final Color accent;
  final IconData icon;

  /// The portfolios that have shipped.
  ///
  /// All four audiences stay visible on the welcome screen — the platform's
  /// promise is that it serves every one of them — but only a shipped role can
  /// be entered. The rest light up as their experience lands on the same shell.
  static const shipped = {
    UserRole.visitor,
    UserRole.corporate,
    UserRole.investor,
    UserRole.entrepreneur,
  };

  bool get isShipped => shipped.contains(this);

  /// Who may ask an exhibitor for a meeting.
  ///
  /// A visitor comes to see the event, not to transact — the ones with a
  /// reason to book a company's time are the founder looking for a pilot and
  /// the fund looking for a deal. The investor portfolio has shipped, so this
  /// is what fills an exhibitor's request list today.
  bool get canRequestMeetings =>
      this == UserRole.entrepreneur || this == UserRole.investor;

  /// Who publishes an info card at `organizations/{uid}`.
  ///
  /// The exhibitor and the founder both do, and they get the same card, the
  /// same QR and the same meeting hours — what differs is that only the
  /// exhibitor holds a booth. Everything keyed off "does this account have a
  /// card" reads this rather than testing for one role and forgetting the
  /// other: the tab bar, the session restore, the onboarding gate.
  bool get publishesCard =>
      this == UserRole.corporate || this == UserRole.entrepreneur;

  static UserRole? fromId(String? id) {
    for (final role in values) {
      if (role.id == id) return role;
    }
    return null;
  }

  /// Aurora palette for this role.
  ///
  /// One bright blob carries the role's identity; the rest are pulled hard
  /// toward deep, cool anchors. Four variations on the accent alone produce a
  /// flat monochrome wash — the dark companions are what give the field depth
  /// while still reading as this role's colour.
  List<Color> get auroraPalette => [
    accent,
    Color.lerp(accent, const Color(0xFF16205C), 0.62)!,
    Color.lerp(accent, const Color(0xFF3D1550), 0.58)!,
    Color.lerp(accent, const Color(0xFF07131F), 0.68)!,
  ];

  /// Palette used before a role is picked — one blob per audience, so the
  /// welcome screen literally shows all four portfolios at once.
  static List<Color> get neutralAuroraPalette =>
      values.map((r) => r.accent).toList(growable: false);
}
