/// What a Take Off QR code says, and how to read one back.
///
/// The payload is a URI rather than a bare id so that a code scanned by the
/// phone's own camera app is at least recognisable as belonging to this event,
/// and so a foreign QR — a Wi-Fi password, a payment code — is rejected
/// instead of being mistaken for a stand.
sealed class QrScan {
  const QrScan();
}

/// An exhibitor's info card, printed on the card standing on their booth.
final class OrganizationScan extends QrScan {
  const OrganizationScan(this.organizationId);

  final String organizationId;
}

/// A gate at the venue. Scanning one is how a visitor checks in.
final class EntryScan extends QrScan {
  const EntryScan(this.gate);

  final String gate;
}

abstract final class QrPayload {
  static const scheme = 'takeoff';

  static String forOrganization(String organizationId) =>
      '$scheme://org/$organizationId';

  static String forEntry(String gate) => '$scheme://entry/$gate';

  /// Returns null for anything that is not a Take Off code, which the scanner
  /// reports rather than acting on.
  static QrScan? parse(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme) return null;

    // `takeoff://org/abc` puts "org" in the host and "abc" in the path, so
    // both halves have to be read to identify the code.
    final segments = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (segments.length < 2) return null;

    return switch (segments.first) {
      'org' => OrganizationScan(segments[1]),
      'entry' => EntryScan(segments[1]),
      _ => null,
    };
  }
}
