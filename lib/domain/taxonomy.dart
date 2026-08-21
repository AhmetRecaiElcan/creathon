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

  /// Company maturity. A venture declares where it is, an investor declares
  /// which of these they write cheques into, and the two are matched.
  ///
  /// `Kurumsal` is the top of the same ladder rather than a separate list: an
  /// established company answering "what stage are you" has to have an honest
  /// answer, and a fund that only meets grown companies has to be able to say
  /// so with the same chips.
  static const stages = <String>[
    'Fikir',
    'Prototip',
    'Pre-seed',
    'Seed',
    'Seri A',
    'Seri B+',
    'Kurumsal',
  ];

  /// How far a company means to reach.
  ///
  /// The second axis after the sector, and the one that decides whether a
  /// conversation is worth having at all: a fund that only backs companies
  /// going global has nothing to say to a venture serving one city, however
  /// well the fields line up.
  static const markets = <String>['Yerel', 'Ulusal', 'Bölgesel', 'Global'];
}
