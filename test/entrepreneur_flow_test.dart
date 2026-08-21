import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/data/organization_repository.dart';
import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/investor_kind.dart';
import 'package:creathon/domain/meeting.dart';
import 'package:creathon/domain/org_kind.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:creathon/features/meetings/meetings_controller.dart';
import 'package:creathon/features/organization/organization_controller.dart';
import 'package:creathon/features/organization/widgets/org_card_sheet.dart';
import 'package:creathon/features/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// The founder's portfolio: a venture card published without a booth, a stage
/// that has to be answered, requests sent to companies and requests received
/// from investors — both on one home screen.
void main() {
  setUpAll(loadAppFonts);

  String uidFor(String email) => 'uid-${email.hashCode}';

  Organization exhibitor({
    String id = 'org-1',
    Set<String> slots = const {'10:00'},
  }) => Organization(
    id: id,
    name: 'Baykar',
    email: 'bilgi@baykar.com',
    address: 'Kurtköy',
    description: 'İnsansız hava araçları.',
    brand: BrandColor.azure,
    standCode: 'A1',
    sector: 'Havacılık & Uzay',
    availability: [for (final time in slots) AvailabilitySlot(time: time)],
  );

  DateTime todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  testWidgets('a founder is asked for the venture, not for a booth', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository(),
    );

    await chooseRole(tester, UserRole.entrepreneur);
    // A founder is a person, unlike an exhibitor: two name fields, not one.
    expect(find.text('Seni tanıyalım.'), findsOneWidget);
    expect(find.text('SOYAD'), findsOneWidget);

    await submitIdentity(tester);
    auth.verified = true;
    await tester.tap(find.text('Doğrulamayı kontrol et'));
    await advance(tester, frames: 10);

    expect(find.text('Girişimini tanıt.'), findsOneWidget);

    // The venture needs a name before anything else.
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 8);
    expect(find.text('Girişiminin adını gir.'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nexora Robotik');
    await tester.enterText(fields.at(1), 'Otonom seyir yazılımı.');
    await tester.enterText(fields.at(2), 'iletisim@nexora.com');
    await advance(tester, frames: 4);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);

    // Stage and field are both required, and the footer says which is missing.
    expect(find.text('Girişimin hangi durumda?'), findsOneWidget);
    expect(find.text('Bir aşama seç'), findsOneWidget);
    await tester.tap(find.text('Seed'));
    await advance(tester, frames: 6);
    expect(find.text('Bir alan seç'), findsOneWidget);

    await scrollTo(tester, find.text('Yapay Zekâ'));
    await tester.tap(find.text('Yapay Zekâ'));
    await advance(tester, frames: 6);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);

    // Straight to the channels, then the card — no floor plan in between.
    expect(find.text('Nerelerden ulaşılsın?'), findsOneWidget);
    expect(find.text('Standını seç.'), findsNothing);
  });

  testWidgets('publishing a venture card needs no booth and opens the app', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final repository = FakeOrganizationRepository();

    await pumpApp(tester, auth: auth, organizations: repository);
    await completeEntrepreneurOnboarding(tester, auth: auth);

    final published = repository.organizations.single;
    expect(published.kind, OrgKind.startup);
    expect(published.name, 'Nexora Robotik');
    expect(published.stage, 'Seed');
    expect(published.sector, 'Yapay Zekâ');
    expect(
      published.standCode,
      isNull,
      reason: 'a founder walks the hall; nothing may reserve a booth for them',
    );

    final container = containerOf(tester);
    expect(container.read(organizationProvider).published, isTrue);
    expect(
      container.read(profileProvider).sectors,
      {'Yapay Zekâ'},
      reason: "the venture's field also orders the founder's programme",
    );

    // The founder's own tabs: a card, and no agenda.
    expect(find.text('KARTIM'), findsOneWidget);
    expect(find.text('AJANDA'), findsNothing);
    expect(find.text('GÖRÜŞMELER'), findsNothing);
  });

  testWidgets('the venture card shows the stage and can be scanned', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository(),
    );
    await completeEntrepreneurOnboarding(tester, auth: auth);

    await tester.tap(find.text('KARTIM'));
    await advance(tester, frames: 10);

    expect(find.text('Kartım'), findsOneWidget);
    // The eyebrow carries what a booth code would on an exhibitor's card.
    expect(
      find.text('GİRİŞİM  ·  Seed  ·  Yapay Zekâ'),
      findsWidgets,
      reason: 'stage and field are the first line of a venture card',
    );
    expect(find.textContaining('Bu karekodu göster'), findsOneWidget);
  });

  testWidgets('a founder asks a company and an investor asks them back', (
    tester,
  ) async {
    const email = 'elif@example.com';
    final founderId = uidFor(email);

    final auth = FakeAuthRepository();
    final meetings = FakeMeetingRepository();
    final organizations = FakeOrganizationRepository([exhibitor()]);

    await pumpApp(
      tester,
      auth: auth,
      organizations: organizations,
      meetings: meetings,
    );
    await completeEntrepreneurOnboarding(tester, auth: auth);

    // Outgoing: the founder picks a company from the list on their home.
    await tester.tap(find.text('Görüşme talebi gönder'));
    await advance(tester, frames: 10);

    expect(find.text('KURUMLAR'), findsOneWidget);
    await tester.tap(find.text('Baykar'));
    await advance(tester, frames: 10);

    await tester.tap(find.text('10:00'));
    await advance(tester, frames: 6);
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 40);

    expect(meetings.meetings.single.organizationId, 'org-1');
    expect(meetings.meetings.single.requesterId, founderId);
    expect(find.text('GÖRÜŞMELERİM'), findsOneWidget);

    // Incoming: an investor asks the founder for one of their own hours. The
    // founder is the host of this one, so it lands in the other section with
    // an answer to give.
    final container = containerOf(tester);
    container.read(organizationProvider.notifier).openSlot(
      const AvailabilitySlot(time: '15:00'),
    );
    await advance(tester, frames: 6);

    await meetings.request(
      Meeting(
        id: Meeting.idFor(
          organizationId: founderId,
          start: todayAt(15, 0),
        ),
        organizationId: founderId,
        organizationName: 'Nexora Robotik',
        requesterId: 'uid-investor',
        requesterName: 'Deniz Arslan',
        requesterEmail: 'deniz@ada.vc',
        requesterCompany: 'Ada Ventures',
        requesterKind: InvestorKind.institutional,
        start: todayAt(15, 0),
        end: todayAt(15, 30),
        location: 'Networking Alanı',
        status: MeetingStatus.requested,
      ),
    );
    await advance(tester, frames: 12);

    expect(find.text('TOPLANTI TALEPLERİ'), findsOneWidget);
    expect(
      find.text('Ada Ventures  ·  Kurumsal'),
      findsOneWidget,
      reason: 'the founder decides on the fund behind the request',
    );

    await tester.tap(find.text('Onayla'));
    await advance(tester, frames: 12);

    final hosted = container
        .read(meetingsProvider)
        .firstWhere((meeting) => meeting.organizationId == founderId);
    expect(hosted.status, MeetingStatus.confirmed);
  });

  testWidgets('an investor finds startups in the picker, ventures first', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final meetings = FakeMeetingRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        exhibitor(),
        Organization(
          id: 'startup-1',
          kind: OrgKind.startup,
          name: 'Nexora Robotik',
          email: 'iletisim@nexora.com',
          description: 'Otonom seyir yazılımı.',
          brand: BrandColor.emerald,
          sector: 'Yapay Zekâ',
          stage: 'Seed',
          availability: const [AvailabilitySlot(time: '11:00')],
        ),
      ]),
      meetings: meetings,
    );
    await completeInvestorOnboarding(tester, auth: auth);

    await tester.tap(find.text('GÖRÜŞMELER'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('Görüşme talebi oluştur'));
    await advance(tester, frames: 10);

    // Both kinds are listed, and the row says the stage rather than the sector.
    expect(find.text('GİRİŞİMLER'), findsOneWidget);
    expect(find.text('KURUMLAR'), findsOneWidget);
    expect(find.text('1 saat açık  ·  Seed'), findsOneWidget);

    await tester.tap(find.text('Nexora Robotik'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('11:00'));
    await advance(tester, frames: 6);
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 10);

    expect(meetings.meetings.single.organizationId, 'startup-1');
    expect(meetings.meetings.single.requesterCompany, 'Ada Ventures');
  });

  testWidgets('a returning founder is restored with their card', (
    tester,
  ) async {
    const email = 'elif@example.com';
    final founderId = uidFor(email);

    final auth = FakeAuthRepository()..verified = true;
    final organizations = FakeOrganizationRepository([
      Organization(
        id: founderId,
        kind: OrgKind.startup,
        name: 'Nexora Robotik',
        email: 'iletisim@nexora.com',
        description: 'Otonom seyir yazılımı.',
        brand: BrandColor.emerald,
        sector: 'Yapay Zekâ',
        stage: 'Prototip',
      ),
    ]);

    await pumpApp(
      tester,
      auth: auth,
      organizations: organizations,
      profiles: FakeProfileStore(
        const UserProfile(
          role: UserRole.entrepreneur,
          firstName: 'Elif',
          lastName: 'Tunca',
          email: email,
          emailVerified: true,
          sectors: {'Yapay Zekâ'},
        ),
      ),
    );

    await chooseRole(tester, UserRole.entrepreneur);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    // The published card is what lets the shell open instead of the setup flow.
    expect(find.text('KARTIM'), findsOneWidget);
    expect(
      containerOf(tester).read(organizationProvider).organization?.stage,
      'Prototip',
    );
  });

  testWidgets('the exhibitor list no longer includes ventures', (tester) async {
    // The 3D hall and the stage programme are built from exhibitors only, so a
    // startup card must never leak into either.
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        exhibitor(),
        Organization(
          id: 'startup-1',
          kind: OrgKind.startup,
          name: 'Nexora Robotik',
          email: 'iletisim@nexora.com',
          description: 'Otonom seyir yazılımı.',
          stage: 'Fikir',
        ),
      ]),
    );
    await completeOnboarding(tester, auth: auth);

    final container = containerOf(tester);
    container.listen(organizationsStreamProvider, (_, _) {});
    await advance(tester, frames: 6);

    expect(container.read(exhibitorsProvider).single.id, 'org-1');
    expect(container.read(startupsProvider).single.id, 'startup-1');
    expect(
      container.read(organizationsByStandProvider).keys,
      ['A1'],
      reason: 'only a booth holder may colour a box on the floor plan',
    );
  });

  testWidgets('a visitor can keep a scanned venture card', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        Organization(
          id: 'startup-1',
          kind: OrgKind.startup,
          name: 'Nexora Robotik',
          email: 'iletisim@nexora.com',
          description: 'Otonom seyir yazılımı.',
          brand: BrandColor.emerald,
          sector: 'Yapay Zekâ',
          stage: 'Seed',
          availability: const [AvailabilitySlot(time: '11:00')],
        ),
      ]),
    );
    await completeOnboarding(tester, auth: auth);

    showOrgCardSheet(
      tester.element(find.byType(Scaffold).first),
      organizationId: 'startup-1',
    );
    await advance(tester, frames: 10);

    expect(find.text('GİRİŞİM  ·  Seed  ·  Yapay Zekâ'), findsOneWidget);
    // A visitor keeps cards but never books time — the same rule as for a
    // company's card.
    expect(find.text('Toplantı talep et'), findsNothing);
  });
}
