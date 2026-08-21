import 'package:flutter/material.dart';

/// What kind of money an investor is bringing.
///
/// The distinction is the first thing a founder wants to know, because it
/// decides what the conversation can even be about: an angel writes a cheque
/// off their own balance sheet and can decide in the hall, a fund brings a
/// mandate, a committee and a process. So it is asked at signup and printed on
/// every request the investor sends, rather than left as a detail in a note.
enum InvestorKind {
  angel(
    id: 'angel',
    label: 'Melek yatırımcı',
    blurb: 'Kendi sermayemle, çoğunlukla erken aşamaya yatırım yapıyorum.',
    icon: Icons.volunteer_activism_rounded,
  ),
  institutional(
    id: 'institutional',
    label: 'Kurumsal yatırımcı',
    blurb: 'Bir fon ya da şirket adına yatırım kararı alıyorum.',
    icon: Icons.account_balance_rounded,
  );

  const InvestorKind({
    required this.id,
    required this.label,
    required this.blurb,
    required this.icon,
  });

  /// Stable key written to Firestore; never localise this.
  final String id;

  final String label;

  /// One line the investor recognises themselves in, shown under the choice so
  /// the two options cannot be confused with each other.
  final String blurb;

  final IconData icon;

  /// What a founder reads on a request, e.g. `Melek yatırımcı`.
  String get shortLabel => switch (this) {
    InvestorKind.angel => 'Melek yatırımcı',
    InvestorKind.institutional => 'Kurumsal',
  };

  static InvestorKind? fromId(String? id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}
