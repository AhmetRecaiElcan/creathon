/// Shared vocabularies. Matching only works if every role tags itself from the
/// same lists, so these are defined once and reused across onboarding, filters
/// and the match explanation.
abstract final class Taxonomy {
  /// Weighted toward the deep-tech verticals T3 Vakfı and Teknofest actually
  /// draw, rather than a generic startup-sector list.
  static const sectors = <String>[
    'Savunma Teknolojileri',
    'Havacılık & Uzay',
    'Yapay Zekâ',
    'Siber Güvenlik',
    'Robotik & Otonom Sistemler',
    'Sağlık Teknolojileri',
    'Enerji & İklim',
    'Tarım Teknolojileri',
    'Mobilite',
    'Fintek',
    'Yazılım & SaaS',
    'Veri & Analitik',
    'Malzeme Bilimi',
    'Eğitim Teknolojileri',
    'Oyun & XR',
    'Nesnelerin İnterneti',
  ];

  /// What the user wants to walk out of the event with. Drives both the agenda
  /// and the match ranking.
  static const goals = <String>[
    'Yatırım almak',
    'Yatırım yapmak',
    'Pilot proje başlatmak',
    'Teknoloji tedarikçisi bulmak',
    'Ortak / kurucu bulmak',
    'Müşteri bulmak',
    'Ekibe yetenek katmak',
    'Mentor bulmak',
    'Mentorluk vermek',
    'Sektörü tanımak',
  ];

  /// Company maturity, used for investor stage filters.
  static const stages = <String>[
    'Fikir',
    'Prototip',
    'Pre-seed',
    'Seed',
    'Seri A',
    'Seri B+',
  ];
}
