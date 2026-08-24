import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/data/organization_repository.dart';
import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/org_kind.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:creathon/features/meetings/meetings_controller.dart';
import 'package:creathon/features/organization/organization_controller.dart';
import 'package:creathon/features/organization/widgets/org_card.dart';
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
    expect(find.text('Bir hedef pazar seç'), findsOneWidget);

    // The third answer an investor screens on: how far this venture reaches.
    await scrollTo(tester, find.text('Ulusal'));
    await tester.tap(find.text('Ulusal'));
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

  testWidgets('a founder sends a request to a company at its stand', (
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

    await tester.tap(find.text('Görüşme talebi gönder'));
    await advance(tester, frames: 10);

    // The company's own hours, with what kind of meeting each one is.
    expect(find.text('Kiminle görüşeceksin?'), findsOneWidget);
    expect(find.text('1 görüşme açık  ·  Yüz yüze'), findsOneWidget);

    await tester.tap(find.text('Baykar'));
    await advance(tester, frames: 10);

    expect(find.text('10:00 – 10:30'), findsOneWidget);
    expect(find.text('Yüz yüze'), findsWidgets);

    await tester.tap(find.text('10:00 – 10:30'));
    await advance(tester, frames: 6);
    // Once a time is chosen the sheet says where it happens, not just when.
    expect(
      find.text('10:00 – 10:30 · yüz yüze, Stand A1'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 40);

    expect(meetings.meetings.single.organizationId, 'org-1');
    expect(meetings.meetings.single.requesterId, founderId);
    expect(meetings.meetings.single.mode, MeetingMode.inPerson);
    expect(find.text('GÖRÜŞMELERİM'), findsOneWidget);
  });

  testWidgets('a founder is never asked to keep hours', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository(),
      meetings: FakeMeetingRepository(),
    );
    await completeEntrepreneurOnboarding(tester, auth: auth);

    // The founder walks the hall asking; there is no availability grid to fill
    // and no "you have not opened any hours yet" to answer.
    expect(find.text('Henüz saat açmadın.'), findsNothing);
    expect(find.text('Henüz görüşme talebin yok.'), findsOneWidget);

    await tester.tap(find.text('PROFİL'));
    await advance(tester, frames: 10);

    expect(find.text('Girişim'), findsOneWidget);
    expect(find.text('TOPLANTI SAATLERİM'), findsNothing);
    expect(
      containerOf(tester).read(hostedMeetingsProvider),
      isEmpty,
      reason: 'nothing may address a request to an account with no hours',
    );
  });

  testWidgets('the request picker offers ventures alongside companies', (
    tester,
  ) async {
    // A fund comes to the fair for the ventures at least as much as for the
    // corporates. A venture is never shown an availability grid, so it declares
    // no hours — and that has to read as "reach me whenever" rather than as a
    // closed row, or a founder would be unreachable by the one audience they
    // came to meet.
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
          brand: BrandColor.emerald,
          sector: 'Yapay Zekâ',
          stage: 'Seed',
        ),
      ]),
      meetings: FakeMeetingRepository(),
    );
    await completeInvestorOnboarding(tester, auth: auth);

    await tester.tap(find.text('GÖRÜŞMELER'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('Görüşme talebi oluştur'));
    await advance(tester, frames: 10);

    expect(find.text('Baykar'), findsOneWidget);
    expect(find.text('Nexora Robotik'), findsOneWidget);

    // The company ticked one in-person hour; the venture ticked nothing and so
    // stands open online.
    //
    // The venture's count is deliberately not asserted. It is the grid minus
    // whatever the clock has already passed, and re-deriving that here would be
    // reimplementing OrganizationSlot.isPast in the test — where it could agree
    // with a bug. The count itself is covered by meeting_room_test; what this
    // flow is about is that both rows appear and say which kind they are.
    expect(find.text('1 görüşme açık  ·  Yüz yüze'), findsOneWidget);
    expect(
      find.textContaining('görüşme açık  ·  Online'),
      findsOneWidget,
    );
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

  testWidgets('a company saves a scanned venture to its own favourites', (
    tester,
  ) async {
    // The mirror of a visitor keeping a stand: a company scans a founder's card
    // to remember them — to hire them, or to talk later — so the save action is
    // on every card but your own, and the list has to live somewhere the
    // exhibitor actually looks.
    const email = 'bilgi@baykar.com';
    final orgId = uidFor(email);

    final auth = FakeAuthRepository()..verified = true;
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        exhibitor(id: orgId),
        Organization(
          id: 'startup-1',
          kind: OrgKind.startup,
          name: 'Nexora Robotik',
          email: 'iletisim@nexora.com',
          description: 'Otonom seyir yazılımı.',
          brand: BrandColor.emerald,
          sector: 'Yapay Zekâ',
          stage: 'Seed',
        ),
      ]),
      profiles: FakeProfileStore(
        const UserProfile(
          role: UserRole.corporate,
          firstName: 'Baykar',
          email: email,
          emailVerified: true,
        ),
      ),
      meetings: FakeMeetingRepository(),
    );

    await chooseRole(tester, UserRole.corporate);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    showOrgCardSheet(
      tester.element(find.byType(Scaffold).first),
      organizationId: 'startup-1',
    );
    await advance(tester, frames: 10);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    await advance(tester, frames: 8);

    final container = containerOf(tester);
    expect(container.read(profileProvider).likedOrgIds, {'startup-1'});

    Navigator.of(tester.element(find.byType(OrgCard).first)).pop();
    await advance(tester, frames: 10);

    expect(find.text('FAVORİLERİM'), findsOneWidget);
    expect(find.text('Nexora Robotik'), findsOneWidget);
    expect(find.text('GİRİŞİM'), findsOneWidget);
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
