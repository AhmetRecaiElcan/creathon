import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/data/expo_repository.dart';
import 'package:creathon/data/organization_repository.dart';
import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:creathon/features/profile/account_deletion.dart';
import 'package:creathon/features/organization/organization_controller.dart';
import 'package:creathon/features/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// The exhibitor flow's promises: a card that publishes, a booth that cannot
/// be taken twice, and a visitor who can keep the card afterwards.
void main() {
  setUpAll(loadAppFonts);

  /// Fills the identity step for an exhibitor — one name, not two — and clears
  /// verification.
  Future<void> registerCorporate(
    WidgetTester tester,
    FakeAuthRepository auth,
  ) async {
    await chooseRole(tester, UserRole.corporate);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nexora Robotik');
    await tester.enterText(fields.at(1), 'bilgi@nexora.com');
    await tester.enterText(fields.at(2), 'takeoff2026');
    await advance(tester, frames: 4);

    await tester.tap(find.text('Hesabımı oluştur'));
    await advance(tester, frames: 10);

    auth.verified = true;
    await tester.tap(find.text('Doğrulamayı kontrol et'));
    await advance(tester, frames: 10);
  }

  Future<void> fillOrgDetails(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'iletisim@nexora.com');
    await tester.enterText(fields.at(1), 'Teknopark, Pendik / İstanbul');
    await tester.enterText(
      fields.at(2),
      'İnsansız kara araçları için otonom seyir yazılımı geliştiriyoruz.',
    );
    await advance(tester, frames: 4);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);
  }

  testWidgets('an exhibitor asks for one name, not a first and a last', (
    tester,
  ) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(),
      organizations: FakeOrganizationRepository(),
    );
    await chooseRole(tester, UserRole.corporate);

    expect(find.text('Kurumunu kaydet.'), findsOneWidget);
    expect(find.text('KURUM ADI'), findsOneWidget);
    expect(find.text('SOYAD'), findsNothing);
  });

  testWidgets('publishing a card claims the booth and opens the app', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final repository = FakeOrganizationRepository();

    await pumpApp(tester, auth: auth, organizations: repository);
    await registerCorporate(tester, auth);

    expect(find.text('Kurumunu tanıt.'), findsOneWidget);
    await fillOrgDetails(tester);

    // Contact channels are all optional.
    expect(find.text('Nerelerden ulaşılsın?'), findsOneWidget);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);

    expect(find.text('Standını seç.'), findsOneWidget);
    expect(
      find.widgetWithText(AccentButton, 'Standı onayla'),
      findsOneWidget,
    );

    final container = containerOf(tester);
    // The booth is picked through the controller: hit-testing a projected 3D
    // quad depends on the panel's exact size, which a test cannot pin down.
    container.read(organizationProvider.notifier).pickStand('A1');
    await advance(tester, frames: 6);

    await tester.tap(find.text('Standı onayla'));
    await advance(tester, frames: 10);

    expect(find.text('Kartın hazır.'), findsOneWidget);
    await tester.tap(find.text('Kartı yayına al'));
    await advance(tester, frames: 14);

    expect(repository.organizations.single.standCode, 'A1');
    expect(repository.organizations.single.name, 'Nexora Robotik');
    expect(container.read(organizationProvider).published, isTrue);

    // The exhibitor's third tab is the card, not an agenda.
    expect(find.text('KARTIM'), findsOneWidget);
    expect(find.text('AJANDA'), findsNothing);
  });

  testWidgets('a booth taken in the meantime sends the user back to the plan', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final repository = FakeOrganizationRepository(const [
      Organization(
        id: 'other-org',
        name: 'OrbitLink',
        email: 'bilgi@orbitlink.com',
        address: 'Ankara',
        description: 'Yer istasyonu ağı.',
        standCode: 'A1',
      ),
    ]);

    await pumpApp(tester, auth: auth, organizations: repository);
    await registerCorporate(tester, auth);
    await fillOrgDetails(tester);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);

    // A1 is already held, so the picker must not offer it.
    final container = containerOf(tester);
    expect(container.read(freeStandCodesProvider), isNot(contains('A1')));

    // Force the clash anyway: this is the race two exhibitors can genuinely
    // hit while both sit on the summary screen.
    container.read(organizationProvider.notifier).pickStand('A1');
    await advance(tester, frames: 6);
    await tester.tap(find.text('Standı onayla'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('Kartı yayına al'));
    await advance(tester, frames: 14);

    expect(find.textContaining('başka bir kurum'), findsOneWidget);
    expect(
      container.read(organizationProvider).published,
      isFalse,
      reason: 'a lost booth must not leave the card marked as live',
    );
  });

  testWidgets('deleting the exhibitor frees its booth and its account', (
    tester,
  ) async {
    const email = 'bilgi@nexora.com';
    final orgId = 'uid-${email.hashCode}';

    final auth = FakeAuthRepository()..verified = true;
    final organizations = FakeOrganizationRepository([
      Organization(
        id: orgId,
        name: 'Nexora Robotik',
        email: email,
        address: 'Pendik',
        description: 'Otonom seyir yazılımı.',
        standCode: 'A1',
      ),
    ]);
    final profiles = FakeProfileStore(
      const UserProfile(
        role: UserRole.corporate,
        firstName: 'Nexora Robotik',
        email: email,
        emailVerified: true,
      ),
    );

    await pumpApp(
      tester,
      auth: auth,
      organizations: organizations,
      profiles: profiles,
    );

    await chooseRole(tester, UserRole.corporate);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    // The exhibitor's home does not watch the floor plan, so the stream has to
    // be subscribed here or reading it cold would report every booth free.
    final container = containerOf(tester);
    container.listen(organizationsStreamProvider, (_, _) {});
    await advance(tester, frames: 6);
    expect(container.read(freeStandCodesProvider), isNot(contains('A1')));

    await container.read(accountDeletionProvider).deleteCorporate();
    await advance(tester, frames: 10);

    expect(organizations.organizations, isEmpty);
    expect(
      container.read(freeStandCodesProvider),
      contains('A1'),
      reason: 'the booth must go back on the floor plan',
    );
    expect(profiles.stored, isNull, reason: 'the user document must go too');
    expect(auth.deletions, 1, reason: 'the account itself must be deleted');
    expect(auth.hasSession, isFalse);
  });

  testWidgets('a stage talk booked at signup reaches the visitor home', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final repository = FakeOrganizationRepository();

    await pumpApp(tester, auth: auth, organizations: repository);
    await registerCorporate(tester, auth);
    await fillOrgDetails(tester);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);

    // The talk is offered on the same step as the booth, and is optional.
    expect(find.text('SAHNE SUNUMU'), findsOneWidget);
    expect(find.text('2. Gün'), findsOneWidget);

    final container = containerOf(tester);
    container.read(organizationProvider.notifier)
      ..pickStand('A1')
      ..setPanelDay(2)
      ..setPanelTime('14:00');
    await advance(tester, frames: 6);

    await tester.tap(find.text('Standı onayla'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('Kartı yayına al'));
    await advance(tester, frames: 14);

    expect(repository.organizations.single.panelDay, 2);
    expect(repository.organizations.single.panelTime, '14:00');
    expect(repository.organizations.single.panelLabel, '2. Gün · 14:00');
  });

  testWidgets('a visitor sees the exhibitors\' stage talks on their home', (
    tester,
  ) async {
    final auth = FakeAuthRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository(const [
        Organization(
          id: 'org-1',
          name: 'Nexora Robotik',
          email: 'bilgi@nexora.com',
          address: 'Pendik',
          description: 'Otonom seyir yazılımı.',
          standCode: 'A1',
          panelDay: 2,
          panelTime: '14:00',
        ),
        // No talk booked: must not appear in the list.
        Organization(
          id: 'org-2',
          name: 'OrbitLink',
          email: 'bilgi@orbitlink.com',
          address: 'Ankara',
          description: 'Yer istasyonu ağı.',
          standCode: 'A3',
        ),
      ]),
    );
    await completeOnboarding(tester, auth: auth);

    expect(find.text('SAHNE SUNUMLARI'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('2. gün'), findsOneWidget);
    expect(find.text('Nexora Robotik'), findsOneWidget);
    expect(find.text('OrbitLink'), findsNothing);
  });

  testWidgets('a visitor keeps a scanned card on their agenda', (tester) async {
    final auth = FakeAuthRepository();
    final repository = FakeOrganizationRepository(const [
      Organization(
        id: 'org-1',
        name: 'Nexora Robotik',
        email: 'bilgi@nexora.com',
        address: 'Pendik',
        description: 'Otonom seyir yazılımı.',
        brand: BrandColor.emerald,
        standCode: 'A1',
        website: 'nexora.com',
      ),
    ]);

    await pumpApp(tester, auth: auth, organizations: repository);
    await completeOnboarding(tester, auth: auth);

    final container = containerOf(tester);
    container.read(profileProvider.notifier).toggleLikedOrg('org-1');
    await advance(tester, frames: 6);

    await tester.tap(find.text('AJANDA'));
    await advance(tester, frames: 10);

    expect(find.text('BEĞENİLEN KURUMLAR'), findsOneWidget);
    expect(find.text('Nexora Robotik'), findsOneWidget);
    expect(find.text('STAND A1'), findsOneWidget);
    expect(find.text('Ajandan boş.'), findsNothing);
  });
}
