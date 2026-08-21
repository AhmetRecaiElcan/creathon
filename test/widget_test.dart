import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/features/organization/widgets/org_card_sheet.dart';
import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:creathon/features/agenda/agenda_providers.dart';
import 'package:creathon/features/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('welcome screen still names all four audiences', (tester) async {
    await pumpApp(tester);

    for (final role in UserRole.values) {
      expect(
        find.text(role.label),
        findsOneWidget,
        reason: '${role.label} must stay visible on the welcome screen',
      );
    }
  });

  test('every audience on the welcome screen has shipped', () {
    // All four portfolios are live, so there is no dimmed card left to assert
    // about — the invariant worth holding is the opposite one. If a fifth
    // audience is ever added unshipped, it belongs outside [UserRole.shipped]
    // and the welcome screen has to dim it again.
    expect(UserRole.shipped, hasLength(UserRole.values.length));
  });

  // One test per role rather than a loop inside one: re-pumping the app reuses
  // the ProviderScope's container, so a second role picked in the same test
  // would land on the first one's onboarding flow.
  for (final role in UserRole.values) {
    testWidgets('${role.label} reaches its own signup', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await chooseRole(tester, role);

      expect(
        find.text(
          role == UserRole.corporate ? 'Kurumunu kaydet.' : 'Seni tanıyalım.',
        ),
        findsOneWidget,
      );
      expect(containerOf(tester).read(profileProvider).role, role);
    });
  }

  testWidgets('a visitor is asked for their profile details first', (
    tester,
  ) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await chooseRole(tester, UserRole.visitor);

    expect(find.text('Seni tanıyalım.'), findsOneWidget);
    expect(find.text('E-POSTA'), findsOneWidget);
    // The goals questionnaire is gone in every place it used to appear.
    expect(find.text('Neden buradasın?'), findsNothing);
  });

  testWidgets('signup refuses an address that is not one', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await chooseRole(tester, UserRole.visitor);
    await submitIdentity(tester, email: 'elif-at-example');

    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
    expect(find.text('E-postanı doğrula.'), findsNothing);
  });

  testWidgets('the flow waits on the verification step until it clears', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);
    await chooseRole(tester, UserRole.visitor);
    await submitIdentity(tester);

    expect(find.text('E-postanı doğrula.'), findsOneWidget);
    expect(auth.sends, 1);

    // Pressing on while the address is still unverified must not advance.
    await tester.tap(find.text('Doğrulamayı kontrol et'));
    await advance(tester, frames: 10);
    expect(find.text('E-postanı doğrula.'), findsOneWidget);

    auth.verified = true;
    await tester.tap(find.text('Doğrulamayı kontrol et'));
    await advance(tester, frames: 10);

    expect(find.text('Hangi alanlar ilgini çekiyor?'), findsOneWidget);
  });

  testWidgets('a verified visitor lands on a home built from the programme', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      sessions: [
        testSession(
          id: 'e1',
          title: 'Yapay Zekâ ile Üretim',
          hour: 10,
          sectors: ['Yapay Zekâ'],
        ),
        testSession(id: 'e2', title: 'Networking Kahvesi', hour: 17),
      ],
    );
    await completeOnboarding(tester, auth: auth);

    expect(find.text('SENİN İÇİN'), findsOneWidget);
    expect(find.text('Yapay Zekâ ile Üretim'), findsOneWidget);
    expect(find.text('TÜM PROGRAM'), findsOneWidget);
  });

  testWidgets('a returning visitor can sign in instead of signing up', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..verified = true;
    final profiles = FakeProfileStore(
      const UserProfile(
        role: UserRole.visitor,
        uid: 'uid-1',
        firstName: 'Elif',
        lastName: 'Tunca',
        email: 'elif@example.com',
        emailVerified: true,
        sectors: {'Yapay Zekâ'},
      ),
    );

    await pumpApp(
      tester,
      auth: auth,
      profiles: profiles,
      sessions: [
        testSession(
          id: 'e1',
          title: 'Yapay Zekâ ile Üretim',
          hour: 10,
          sectors: ['Yapay Zekâ'],
        ),
      ],
    );
    await chooseRole(tester, UserRole.visitor);

    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    // Sign-in asks for two things, not four: the name belongs to the account.
    expect(find.text('Tekrar hoş geldin.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'elif@example.com');
    await tester.enterText(fields.at(1), 'takeoff2026');
    await advance(tester, frames: 4);

    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 14);

    // Straight into the app: nothing was left to ask.
    expect(find.text('SENİN İÇİN'), findsOneWidget);
    final profile = containerOf(tester).read(profileProvider);
    expect(profile.firstName, 'Elif');
    expect(profile.sectors, {'Yapay Zekâ'});
  });

  testWidgets('signing in resumes an account that never picked interests', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..verified = true;
    final profiles = FakeProfileStore(
      const UserProfile(
        role: UserRole.visitor,
        uid: 'uid-1',
        firstName: 'Elif',
        lastName: 'Tunca',
        email: 'elif@example.com',
        emailVerified: true,
      ),
    );

    await pumpApp(tester, auth: auth, profiles: profiles);
    await chooseRole(tester, UserRole.visitor);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'elif@example.com');
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 14);

    expect(find.text('Hangi alanlar ilgini çekiyor?'), findsOneWidget);
  });

  testWidgets('a visitor address cannot be used to enter as an exhibitor', (
    tester,
  ) async {
    // One account is one role: the profile, the organisation and the meetings
    // are all keyed by the same uid, so letting this through would build a
    // company on top of somebody's visitor profile.
    final auth = FakeAuthRepository()..verified = true;
    final profiles = FakeProfileStore(
      const UserProfile(
        role: UserRole.visitor,
        uid: 'uid-1',
        firstName: 'Elif',
        lastName: 'Tunca',
        email: 'elif@example.com',
        emailVerified: true,
        sectors: {'Yapay Zekâ'},
      ),
    );

    await pumpApp(
      tester,
      auth: auth,
      profiles: profiles,
      organizations: FakeOrganizationRepository(),
    );
    await chooseRole(tester, UserRole.corporate);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'elif@example.com');
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 14);

    expect(find.textContaining('ziyaretçi hesabına ait'), findsOneWidget);
    expect(
      auth.hasSession,
      isFalse,
      reason: 'a refused attempt must not leave a session behind',
    );
    expect(find.text('Kurumunu tanıt.'), findsNothing);
  });

  testWidgets('a visitor is not offered a meeting request', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        Organization(
          id: 'org-1',
          name: 'Nexora Robotik',
          email: 'bilgi@nexora.com',
          address: 'Pendik',
          description: 'Otonom seyir yazılımı.',
          standCode: 'A1',
          availability: const [AvailabilitySlot(time: '10:00')],
        ),
      ]),
    );
    await completeOnboarding(tester, auth: auth);

    showOrgCardSheet(
      tester.element(find.byType(Scaffold).first),
      organizationId: 'org-1',
    );
    await advance(tester, frames: 10);

    // The card still opens and can be kept; only booking the company's time
    // belongs to the founder and the fund.
    expect(find.text('Nexora Robotik'), findsWidgets);
    expect(find.text('Toplantı talep et'), findsNothing);
  });

  testWidgets('adding an event from home puts it on the agenda', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      sessions: [
        testSession(
          id: 'e1',
          title: 'Yapay Zekâ ile Üretim',
          hour: 10,
          sectors: ['Yapay Zekâ'],
        ),
      ],
    );
    await completeOnboarding(tester, auth: auth);

    final container = containerOf(tester);
    expect(container.read(savedSessionsProvider), isEmpty);

    // The only add control on screen, since the programme holds one session.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await advance(tester, frames: 8);

    expect(container.read(savedSessionsProvider).single.id, 'e1');

    await tester.tap(find.text('AJANDA'));
    await advance(tester, frames: 10);

    expect(find.text('Yapay Zekâ ile Üretim'), findsOneWidget);
    expect(find.text('Ajandan boş.'), findsNothing);
  });
}
