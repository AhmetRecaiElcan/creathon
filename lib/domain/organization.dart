import 'package:flutter/material.dart';

import 'availability_slot.dart';
import 'brand_color.dart';

/// Which field on the organisation a link came from.
///
/// Carried on the link so the card can offer to edit the exact channel the
/// owner tapped, rather than making them hunt for it in a form.
enum OrgChannel {
  website('Web sitesi', 'kurum.com'),
  email('E-posta', 'iletisim@kurum.com'),
  instagram('Instagram', '@kurum'),
  linkedin('LinkedIn', 'kurum  ·  ya da tam bağlantı'),
  phone('Telefon', '+90 5xx xxx xx xx');

  const OrgChannel(this.label, this.hint);

  final String label;
  final String hint;
}

/// One outward-facing channel on an organisation's info card.
@immutable
class OrgLink {
  const OrgLink({
    required this.channel,
    required this.icon,
    required this.url,
    required this.display,
  });

  final OrgChannel channel;

  String get label => channel.label;

  final IconData icon;

  /// Fully-qualified target handed to the platform launcher.
  final String url;

  /// What the user reads — the handle or domain, not the whole URL.
  final String display;
}

/// An exhibiting company: everything on its info card, plus the stand it stands
/// on.
///
/// Keyed by the account's uid, so the organisation *is* the corporate user's
/// profile rather than something hanging off it.
@immutable
class Organization {
  const Organization({
    required this.id,
    this.name = '',
    this.email = '',
    this.address = '',
    this.description = '',
    this.brand = BrandColor.azure,
    this.logoBase64,
    this.standCode,
    this.sector,
    this.website,
    this.instagram,
    this.linkedin,
    this.phone,
    this.availability = const [],
  });

  final String id;

  final String name;

  /// Public contact address on the card. Not necessarily the login address —
  /// a company signs in as `bilgi@` but publishes `iletisim@`.
  final String email;

  final String address;

  /// The "who we are" paragraph the card is built around.
  final String description;

  final BrandColor brand;

  /// Logo held inline as base64, the same trade-off as the visitor avatar: no
  /// Storage bucket, no bucket rules, and it is already loaded by the time the
  /// card or the 3D stand needs to draw it.
  final String? logoBase64;

  /// Booth code from [ExpoLayout]. Assigned once and never changed — the
  /// reservation is what makes the floor plan trustworthy.
  final String? standCode;

  final String? sector;

  final String? website;
  final String? instagram;
  final String? linkedin;
  final String? phone;

  /// Half-hour slots the exhibitor opened for meetings, in time order.
  ///
  /// Wall-clock times rather than timestamps because availability is a daily
  /// routine ("we take meetings from two to four"), not a set of specific
  /// instants — and because it stays readable in the console.
  final List<AvailabilitySlot> availability;

  /// Just the times, for the checks that only care whether a slot exists.
  Set<String> get openTimes => {for (final slot in availability) slot.time};

  /// Reads the slot list, tolerating the flat `["10:00"]` shape an earlier
  /// build wrote. Those become in-person slots with no note, which is what
  /// they meant when there was nothing else to say.
  static List<AvailabilitySlot> _readAvailability(Map<String, Object?> map) {
    final rich = (map['availability'] as List?)
        ?.whereType<Map>()
        .map((entry) => AvailabilitySlot.fromMap(entry.cast()))
        .nonNulls
        .toList();
    if (rich != null && rich.isNotEmpty) {
      rich.sort((a, b) => a.time.compareTo(b.time));
      return rich;
    }

    // Built fresh rather than falling back to a const list: the sort below
    // would throw on an unmodifiable one.
    final legacy = [...?(map['availableSlots'] as List?)?.whereType<String>()]
      ..sort();
    return [for (final time in legacy) AvailabilitySlot(time: time)];
  }

  Color get color => brand.color;

  /// The sector, or null when it was never chosen or was cleared. Callers must
  /// not have to tell an empty string apart from an absent field.
  String? get sectorLabel {
    final value = sector?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Up to two letters, used wherever there is no logo to draw.
  String get initials {
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  /// Everything needed before the card can be published.
  ///
  /// The address and the description are required because the card exists to
  /// answer "who are you and where do I find you"; a card missing either is
  /// not worth a visitor's scan.
  bool get isComplete =>
      name.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      description.trim().isNotEmpty &&
      standCode != null;

  /// Reachable channels, in the order a visitor is most likely to want them.
  /// Empty fields are simply absent rather than rendered as dead rows.
  List<OrgLink> get links => [
    if (website != null && website!.trim().isNotEmpty)
      OrgLink(
        channel: OrgChannel.website,
        icon: Icons.language_rounded,
        url: _withScheme(website!),
        display: _bareDomain(website!),
      ),
    if (email.trim().isNotEmpty)
      OrgLink(
        channel: OrgChannel.email,
        icon: Icons.mail_outline_rounded,
        url: 'mailto:${email.trim()}',
        display: email.trim(),
      ),
    if (instagram != null && instagram!.trim().isNotEmpty)
      OrgLink(
        channel: OrgChannel.instagram,
        icon: Icons.camera_alt_outlined,
        url: 'https://instagram.com/${_handle(instagram!)}',
        display: '@${_handle(instagram!)}',
      ),
    if (linkedin != null && linkedin!.trim().isNotEmpty)
      OrgLink(
        channel: OrgChannel.linkedin,
        icon: Icons.business_center_outlined,
        url: _linkedinUrl(linkedin!),
        display: _handle(linkedin!),
      ),
    if (phone != null && phone!.trim().isNotEmpty)
      OrgLink(
        channel: OrgChannel.phone,
        icon: Icons.call_outlined,
        url: 'tel:${phone!.replaceAll(RegExp(r'[^\d+]'), '')}',
        display: phone!.trim(),
      ),
  ];

  /// A company types `firma.com`, not `https://firma.com`.
  static String _withScheme(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://$value';
  }

  static String _bareDomain(String raw) => raw
      .trim()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/$'), '');

  /// Accepts `@firma`, `firma`, or a pasted profile URL, and keeps the handle.
  static String _handle(String raw) {
    var value = raw.trim().replaceFirst(RegExp(r'^@'), '');
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.replaceFirst(
      RegExp(r'^(www\.)?(instagram\.com|linkedin\.com)/(company/|in/)?'),
      '',
    );
    return value.replaceFirst(RegExp(r'/$'), '');
  }

  /// LinkedIn splits companies and people across two path prefixes, and
  /// guessing wrong lands the visitor on a 404 — so a pasted URL is kept whole
  /// and only a bare handle is assumed to be a company page.
  static String _linkedinUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.contains('linkedin.com')) return 'https://$value';
    return 'https://linkedin.com/company/${_handle(value)}';
  }

  Organization copyWith({
    String? name,
    String? email,
    String? address,
    String? description,
    BrandColor? brand,
    String? logoBase64,
    String? standCode,
    String? sector,
    String? website,
    String? instagram,
    String? linkedin,
    String? phone,
    List<AvailabilitySlot>? availability,
    bool clearLogo = false,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      address: address ?? this.address,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      logoBase64: clearLogo ? null : (logoBase64 ?? this.logoBase64),
      standCode: standCode ?? this.standCode,
      sector: sector ?? this.sector,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      linkedin: linkedin ?? this.linkedin,
      phone: phone ?? this.phone,
      availability: availability ?? this.availability,
    );
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'email': email,
    'address': address,
    'description': description,
    'brand': brand.id,
    'color': brand.hex,
    'logoBase64': logoBase64,
    'standCode': standCode,
    'sector': sector,
    'website': website,
    'instagram': instagram,
    'linkedin': linkedin,
    'phone': phone,
    'availability': [for (final slot in availability) slot.toMap()],
  };

  static Organization fromMap(Map<String, Object?> map, {required String id}) {
    // `brand` is the palette key; `color` is the hex written alongside it for
    // other tools. Falling back to the hex keeps a stand assigned by hand
    // outside the app rendering in the colour that was asked for.
    final brand = map['brand'] is String
        ? BrandColor.fromId(map['brand'] as String)
        : BrandColor.fromHex(map['color'] as String?);

    return Organization(
      id: id,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      brand: brand,
      logoBase64: map['logoBase64'] as String?,
      standCode: (map['standCode'] as String?)?.trim(),
      sector: map['sector'] as String?,
      website: map['website'] as String?,
      instagram: map['instagram'] as String?,
      linkedin: map['linkedin'] as String?,
      phone: map['phone'] as String?,
      availability: _readAvailability(map),
    );
  }
}
