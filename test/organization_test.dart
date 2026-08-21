import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/organization.dart';
import 'package:flutter_test/flutter_test.dart';

/// A company types a handle, not a URL, and the card has to turn that into
/// something a phone can actually open.
void main() {
  Organization org({
    String? website,
    String? instagram,
    String? linkedin,
    String? phone,
    String email = 'bilgi@nexora.com',
  }) => Organization(
    id: 'org-1',
    name: 'Nexora Robotik',
    email: email,
    website: website,
    instagram: instagram,
    linkedin: linkedin,
    phone: phone,
  );

  String urlFor(Organization organization, String label) =>
      organization.links.firstWhere((link) => link.label == label).url;

  group('Organization.links', () {
    test('adds a scheme to a bare domain', () {
      expect(urlFor(org(website: 'nexora.com'), 'Web sitesi'),
          'https://nexora.com');
    });

    test('leaves an already qualified URL alone', () {
      expect(urlFor(org(website: 'http://nexora.com'), 'Web sitesi'),
          'http://nexora.com');
    });

    test('shows the domain rather than the whole URL', () {
      final link = org(
        website: 'https://nexora.com/',
      ).links.firstWhere((l) => l.label == 'Web sitesi');

      expect(link.display, 'nexora.com');
    });

    test('accepts an Instagram handle with or without the at sign', () {
      const expected = 'https://instagram.com/nexora';
      expect(urlFor(org(instagram: '@nexora'), 'Instagram'), expected);
      expect(urlFor(org(instagram: 'nexora'), 'Instagram'), expected);
      expect(
        urlFor(org(instagram: 'instagram.com/nexora'), 'Instagram'),
        expected,
      );
    });

    test('a bare LinkedIn handle is treated as a company page', () {
      expect(
        urlFor(org(linkedin: 'nexora'), 'LinkedIn'),
        'https://linkedin.com/company/nexora',
      );
    });

    test('a pasted LinkedIn URL is kept whole', () {
      // Guessing /company/ for a personal profile would send the visitor to a
      // 404, so anything that already looks like a URL is left as typed.
      expect(
        urlFor(org(linkedin: 'https://linkedin.com/in/deniz'), 'LinkedIn'),
        'https://linkedin.com/in/deniz',
      );
    });

    test('strips formatting out of a phone number', () {
      expect(
        urlFor(org(phone: '+90 532 111 22 33'), 'Telefon'),
        'tel:+905321112233',
      );
    });

    test('empty channels do not become dead rows', () {
      final links = org(
        website: '',
        instagram: '   ',
        linkedin: null,
        phone: '',
      ).links;

      expect(links.map((l) => l.label), ['E-posta']);
    });
  });

  group('Organization', () {
    test('is incomplete until it holds a booth', () {
      const base = Organization(
        id: 'org-1',
        name: 'Nexora',
        email: 'bilgi@nexora.com',
        address: 'Pendik',
        description: 'Otonom seyir yazılımı.',
      );

      expect(base.isComplete, isFalse);
      expect(base.copyWith(standCode: 'A3').isComplete, isTrue);
    });

    test('survives a round trip through Firestore', () {
      const original = Organization(
        id: 'org-1',
        name: 'Nexora Robotik',
        email: 'bilgi@nexora.com',
        address: 'Pendik',
        description: 'Otonom seyir yazılımı.',
        brand: BrandColor.emerald,
        standCode: 'A3',
        sector: 'Robotik & Otonom Sistemler',
        website: 'nexora.com',
      );

      final restored = Organization.fromMap(original.toMap(), id: 'org-1');

      expect(restored.name, original.name);
      expect(restored.brand, BrandColor.emerald);
      expect(restored.standCode, 'A3');
      expect(restored.website, 'nexora.com');
    });

    test('falls back to the hex when the palette key is missing', () {
      // A stand assigned by a tool that never loaded this enum still renders
      // in the colour that was asked for.
      final restored = Organization.fromMap(
        {'name': 'Nexora', 'color': '#2FD98A'},
        id: 'org-1',
      );

      expect(restored.brand, BrandColor.emerald);
    });

    test('an empty sector reads as absent', () {
      expect(
        const Organization(id: 'x', sector: '   ').sectorLabel,
        isNull,
      );
    });
  });
}
