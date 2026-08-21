import 'package:creathon/domain/qr_payload.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scanner acts on whatever this returns, so the risk worth covering is
/// not "does a good code parse" but "does a foreign code get refused".
void main() {
  group('QrPayload', () {
    test('round-trips an organisation code', () {
      final scan = QrPayload.parse(QrPayload.forOrganization('org-1'));

      expect(scan, isA<OrganizationScan>());
      expect((scan! as OrganizationScan).organizationId, 'org-1');
    });

    test('round-trips an entry code', () {
      final scan = QrPayload.parse(QrPayload.forEntry('A'));

      expect(scan, isA<EntryScan>());
      expect((scan! as EntryScan).gate, 'A');
    });

    test('tolerates surrounding whitespace from a scanner', () {
      expect(QrPayload.parse('  takeoff://org/org-1  '), isA<OrganizationScan>());
    });

    test('refuses codes that belong to something else', () {
      for (final foreign in [
        'https://example.com',
        'WIFI:S:takeoff;T:WPA;P:secret;;',
        'org-1',
        'takeoff://',
        'takeoff://org',
        'takeoff://unknown/org-1',
        '',
      ]) {
        expect(
          QrPayload.parse(foreign),
          isNull,
          reason: '"$foreign" must not be read as a Take Off code',
        );
      }
    });

    test('refuses a null payload', () {
      expect(QrPayload.parse(null), isNull);
    });
  });
}
