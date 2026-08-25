import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/investor_kind.dart';
import 'package:creathon/domain/match_insight.dart';
import 'package:creathon/domain/meeting.dart';
import 'package:creathon/domain/org_kind.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:creathon/features/organization/widgets/org_card.dart';
import 'package:creathon/features/organization/widgets/org_card_sheet.dart';
import 'package:creathon/features/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// The investor portfolio's promises: the fund is asked for at signup, no card
/// is ever published, and a request can be created, sent and tracked.
void main() {
  setUpAll(loadAppFonts);

  Organization exhibitor({
    String id = 'org-1',
    String name = 'Nexora Robotik',
    Set<String> slots = const {'10:00'},
  }) => Organization(
    id: id,
    name: name,
    email: 'bilgi@nexora.com',
    address: 'Pendik',
    description: 'Otonom seyir yazılımı.',
    brand: BrandColor.emerald,
    standCode: 'A1',
    sector: 'Robotik & Otonom Sistemler',
    availability: [for (final time in slots) AvailabilitySlot(time: time)],
  );

  testWidgets('the investor step refuses to pass without a fund and a kind', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await chooseRole(tester, UserRole.investor);
    await submitIdentity(tester);

    auth.verified = true;
    await tester.tap(find.text('Doğrulamayı kontrol et'));
    await advance(tester, frames: 10);

    expect(find.text('Kimin adına yatırım yapıyorsun?'), findsOneWidget);

    // Neither answer given.
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 8);
    expect(
      find.text('Yatırım yaptığın şirketin ya da fonun adını gir.'),
      findsOneWidget,
    );

    // The fund alone is not an introduction either.
    await tester.enterText(find.byType(TextField).first, 'Ada Ventures');
    await advance(tester, frames: 4);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 8);
    expect(find.text('Melek mi kurumsal mı, birini seç.'), findsOneWidget);

    await tester.tap(find.text('Melek yatırımcı'));
    await advance(tester, frames: 6);
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);

    // Only now does the thesis step appear, framed as investment rather than
    // as interests.
    expect(find.text('Hangi alanlara yatırım yapıyorsun?'), findsOneWidget);
  });

  testWidgets('a signed-up investor gets a meetings tab and no card', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final profiles = FakeProfileStore();

    await pumpApp(tester, auth: auth, profiles: profiles);
    await completeInvestorOnboarding(
      tester,
      auth: auth,
      company: 'Ada Ventures',
      kind: InvestorKind.institutional,
    );

    final profile = containerOf(tester).read(profileProvider);
    expect(profile.role, UserRole.investor);
    expect(profile.companyName, 'Ada Ventures');
    expect(profile.investorKind, InvestorKind.institutional);
    expect(
      profiles.stored?.companyName,
      'Ada Ventures',
      reason: 'the fund has to survive a reinstall, not just this session',
    );

    // The investor publishes nothing, so the exhibitor's card tab is not on the
    // bar — and neither is the visitor's agenda.
    expect(find.text('GÖRÜŞMELER'), findsOneWidget);
    expect(find.text('KARTIM'), findsNothing);
    expect(find.text('AJANDA'), findsNothing);

    await tester.tap(find.text('GÖRÜŞMELER'));
    await advance(tester, frames: 10);

    expect(find.text('Görüşmeler'), findsOneWidget);
    expect(find.text('Henüz talep göndermedin.'), findsOneWidget);
    expect(find.text('Görüşme talebi oluştur'), findsOneWidget);
  });

  testWidgets('an investor creates a request from the company list', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final meetings = FakeMeetingRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([exhibitor()]),
      meetings: meetings,
    );
    await completeInvestorOnboarding(tester, auth: auth);

    await tester.tap(find.text('GÖRÜŞMELER'));
    await advance(tester, frames: 10);

    await tester.tap(find.text('Görüşme talebi oluştur'));
    await advance(tester, frames: 10);

    expect(find.text('Kiminle görüşeceksin?'), findsOneWidget);
    expect(
      find.text('1 görüşme açık  ·  Yüz yüze'),
      findsOneWidget,
    );

    await tester.tap(find.text('Nexora Robotik'));
    await advance(tester, frames: 10);

    // The picker hands over to the request sheet, which shows how the request
    // will introduce itself.
    expect(find.text('SAAT SEÇ'), findsOneWidget);
    expect(
      find.text('Ada Ventures  ·  Melek yatırımcı olarak gönderilecek.'),
      findsOneWidget,
    );

    await tester.tap(find.text('10:00 – 10:30'));
    await advance(tester, frames: 6);
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 10);

    expect(find.text('Talebin gönderildi.'), findsOneWidget);

    final sent = meetings.meetings.single;
    expect(sent.organizationId, 'org-1');
    expect(sent.startLabel, '10:00');
    expect(sent.requesterCompany, 'Ada Ventures');
    expect(sent.requesterKind, InvestorKind.angel);
    expect(
      sent.requesterDetail,
      'Ada Ventures  ·  Melek yatırımcı',
      reason: 'the exhibitor decides on the fund, not on a bare name',
    );

    // The sheet closes itself and the request is on the meetings tab.
    await advance(tester, frames: 30);
    expect(find.text('TALEPLERİM'), findsOneWidget);
  });

  testWidgets('the investor home ranks cards and the events tab holds the rest', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        // An exhibitor with a stage talk, and two ventures — one in the
        // investor's own field, one outside it.
        Organization(
          id: 'org-1',
          name: 'Baykar',
          email: 'bilgi@baykar.com',
          address: 'Kurtköy',
          description: 'İnsansız hava araçları.',
          standCode: 'A1',
          sector: 'Havacılık & Uzay',
          panelDay: 1,
          panelTime: '14:00',
        ),
        const Organization(
          id: 'startup-1',
          kind: OrgKind.startup,
          name: 'Zeta Uzay',
          email: 'iletisim@zeta.com',
          description: 'Küp uydu itki sistemleri.',
          sector: 'Havacılık & Uzay',
          stage: 'Pre-seed',
        ),
        const Organization(
          id: 'startup-2',
          kind: OrgKind.startup,
          name: 'Nexora Robotik',
          email: 'iletisim@nexora.com',
          description: 'Otonom seyir yazılımı.',
          sector: 'Yapay Zekâ',
          stage: 'Seed',
          market: 'Ulusal',
        ),
      ]),
      meetings: FakeMeetingRepository(),
      sessions: [
        testSession(
          id: 'e1',
          title: 'Yapay Zekâ ile Üretim',
          hour: 10,
          sectors: ['Yapay Zekâ'],
        ),
      ],
    );
    await completeInvestorOnboarding(
      tester,
      auth: auth,
      sectors: const ['Yapay Zekâ'],
      stages: const ['Seed'],
      markets: const ['Ulusal'],
    );

    // The home screen is the ranked list. Nexora matches all three criteria and
    // leads; Zeta matches none of them and drops below the fold.
    expect(find.text('SENİN İÇİN'), findsOneWidget);
    expect(find.text('SIRALAMA ÖLÇÜTÜM'), findsOneWidget);
    expect(
      find.text('Yapay Zekâ  ·  Seed  ·  Ulusal'),
      findsNWidgets(2),
      reason: 'once as the stated criteria, once as what the top row matched',
    );
    expect(
      find.text('100'),
      findsOneWidget,
      reason: 'the badge is a percentage now: Nexora hits all three criteria, '
          'so it scores the deterministic maximum',
    );
    expect(
      find.text('ETİKET EŞLEŞMESİYLE SIRALANDI'),
      findsOneWidget,
      reason: 'no model answered in this test, and the chip says so rather '
          'than claiming a ranking the AI did not produce',
    );
    expect(find.text('DİĞERLERİ'), findsOneWidget);
    expect(find.text('Zeta Uzay'), findsOneWidget);

    // The programme and the stage talks are a different job, on their own tab.
    expect(find.text('SAHNE SUNUMLARI'), findsNothing);

    // Tapping a venture opens the same card a scan would.
    await tester.tap(find.text('Nexora Robotik'));
    await advance(tester, frames: 10);
    expect(find.text('Otonom seyir yazılımı.'), findsOneWidget);
    Navigator.of(tester.element(find.byType(OrgCard).first)).pop();
    await advance(tester, frames: 10);

    await tester.tap(find.text('ETKİNLİKLER'));
    await advance(tester, frames: 12);

    expect(find.text('Etkinlikler'), findsOneWidget);
    expect(find.text('SAHNE SUNUMLARI'), findsOneWidget);
    expect(find.text('Baykar'), findsWidgets);
    expect(find.text('Yapay Zekâ ile Üretim'), findsOneWidget);
  });

  testWidgets('the model outranks the tags and says why', (tester) async {
    final auth = FakeAuthRepository();
    // The deterministic scorer would put Nexora first: it hits all three
    // criteria and Zeta hits none. The model has read both cards and disagrees,
    // which is the entire reason it is here.
    final ai = FakeAiMatchRepository(const [
      AiMatch(
        orgId: 'startup-1',
        score: 92,
        headline: 'İtki sistemleri',
        reason: 'Küp uydu itkisi, portföyündeki savunma yatırımlarının '
            'doğrudan tedarik zinciri.',
      ),
      AiMatch(
        orgId: 'startup-2',
        score: 38,
        headline: 'Etiket uyumu',
        reason: 'Alan etiketi tutuyor ama anlattığı iş yatırım tezinin '
            'dışında.',
      ),
    ]);

    await pumpApp(
      tester,
      auth: auth,
      aiMatches: ai,
      organizations: FakeOrganizationRepository([
        const Organization(
          id: 'startup-1',
          kind: OrgKind.startup,
          name: 'Zeta Uzay',
          email: 'iletisim@zeta.com',
          description: 'Küp uydu itki sistemleri.',
          sector: 'Havacılık & Uzay',
          stage: 'Pre-seed',
        ),
        const Organization(
          id: 'startup-2',
          kind: OrgKind.startup,
          name: 'Nexora Robotik',
          email: 'iletisim@nexora.com',
          description: 'Otonom seyir yazılımı.',
          sector: 'Yapay Zekâ',
          stage: 'Seed',
          market: 'Ulusal',
        ),
      ]),
      meetings: FakeMeetingRepository(),
    );
    await completeInvestorOnboarding(
      tester,
      auth: auth,
      sectors: const ['Yapay Zekâ'],
      stages: const ['Seed'],
      markets: const ['Ulusal'],
    );

    // The chip names the engine, so a ranking nobody can reproduce by eye at
    // least says what produced it.
    expect(
      find.text('YAPAY ZEKÂ SIRALADI  ·  GEMINI 2.5'),
      findsWidgets,
    );

    // Zeta is the one above the floor now, and its caption is the model's
    // sentence rather than a restatement of its tags.
    expect(find.text('SENİN İÇİN'), findsOneWidget);
    expect(find.text('92'), findsWidgets);
    expect(
      find.textContaining('portföyündeki savunma yatırımlarının'),
      findsWidgets,
    );

    // Nexora keeps its three matching tags and still drops below the fold: the
    // model's score is what orders the list once there is one.
    expect(find.text('DİĞERLERİ'), findsOneWidget);
    await scrollTo(tester, find.text('Nexora Robotik'));
    expect(find.text('38'), findsOneWidget);

    // One call, not one per rebuild. The onboarding flow alone rebuilds the
    // tree dozens of times, and each of those is a paid generation if the
    // future is keyed on anything that moves.
    expect(ai.calls, 1);
  });

  testWidgets('a company with no open hours cannot be asked', (tester) async {
    final auth = FakeAuthRepository();
    final meetings = FakeMeetingRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        exhibitor(id: 'org-2', name: 'Kapalı Teknoloji', slots: const {}),
      ]),
      meetings: meetings,
    );
    await completeInvestorOnboarding(tester, auth: auth);

    await tester.tap(find.text('GÖRÜŞMELER'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('Görüşme talebi oluştur'));
    await advance(tester, frames: 10);

    // Still listed — knowing the company is here is worth something — but the
    // row says why it cannot be tapped, and tapping it does nothing.
    expect(find.text('Henüz görüşme saati açmadı'), findsOneWidget);
    await tester.tap(find.text('Kapalı Teknoloji'));
    await advance(tester, frames: 10);

    expect(find.text('SAAT SEÇ'), findsNothing);
    expect(meetings.meetings, isEmpty);
  });

  testWidgets('the fund and the kind can be changed from the profile', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final profiles = FakeProfileStore();

    await pumpApp(tester, auth: auth, profiles: profiles);
    await completeInvestorOnboarding(tester, auth: auth);

    await tester.tap(find.text('PROFİL'));
    await advance(tester, frames: 10);

    expect(find.text('YATIRIMCI PROFİLİM'), findsOneWidget);
    expect(find.text('Ada Ventures'), findsOneWidget);

    // Switching to institutional is one deliberate tap, no form.
    await scrollTo(tester, find.text('Kurumsal yatırımcı'));
    await tester.tap(find.text('Kurumsal yatırımcı'));
    await advance(tester, frames: 8);
    expect(
      containerOf(tester).read(profileProvider).investorKind,
      InvestorKind.institutional,
    );

    await scrollTo(tester, find.byIcon(Icons.edit_rounded));
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await advance(tester, frames: 12);

    await tester.enterText(find.byType(TextField).last, 'Boğaziçi Ventures');
    await advance(tester, frames: 4);
    await tester.tap(find.widgetWithText(AccentButton, 'Kaydet'));
    await advance(tester, frames: 10);

    expect(
      containerOf(tester).read(profileProvider).companyName,
      'Boğaziçi Ventures',
    );
    expect(
      profiles.stored?.investorKind,
      InvestorKind.institutional,
      reason: 'both edits have to reach the account document',
    );
  });

  testWidgets('signing back in resumes an investor mid-signup', (
    tester,
  ) async {
    // The account exists and is verified, but the run that created it stopped
    // before the thesis step — so the fund it did answer has to come back with
    // it rather than be asked for twice.
    final auth = FakeAuthRepository()..verified = true;
    final profiles = FakeProfileStore(
      const UserProfile(
        role: UserRole.investor,
        uid: 'uid-1',
        firstName: 'Deniz',
        lastName: 'Arslan',
        email: 'deniz@ada.vc',
        emailVerified: true,
        companyName: 'Ada Ventures',
        investorKind: InvestorKind.institutional,
      ),
    );

    await pumpApp(tester, auth: auth, profiles: profiles);
    await chooseRole(tester, UserRole.investor);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'deniz@ada.vc');
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    expect(find.text('Kimin adına yatırım yapıyorsun?'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'Ada Ventures',
    );

    // The kind is still selected, so Devam passes straight through.
    await tester.tap(find.text('Devam'));
    await advance(tester, frames: 10);
    expect(find.text('Hangi alanlara yatırım yapıyorsun?'), findsOneWidget);
  });

  testWidgets('an investor is offered a meeting on a scanned card', (
    tester,
  ) async {
    final auth = FakeAuthRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([exhibitor()]),
      meetings: FakeMeetingRepository(),
    );
    await completeInvestorOnboarding(tester, auth: auth);

    // The card sheet is what a scan, a booth tap and the watchlist all open, so
    // the request action has to be on it — the mirror of the visitor test that
    // asserts the same card offers no such thing.
    showOrgCardSheet(
      tester.element(find.byType(Scaffold).first),
      organizationId: 'org-1',
    );
    await advance(tester, frames: 10);

    expect(find.text('Toplantı talep et'), findsOneWidget);
    await tester.tap(find.text('Toplantı talep et'));
    await advance(tester, frames: 10);
    expect(find.text('SAAT SEÇ'), findsOneWidget);
  });

  testWidgets('an investor can end a confirmed meeting with a venture', (
    tester,
  ) async {
    // submitIdentity's default address, and the uid FakeAuthRepository mints
    // for it — the meeting has to belong to the account that signs in.
    const email = 'elif@example.com';
    final investorId = 'uid-${email.hashCode}';
    final start = testNow.subtract(const Duration(minutes: 20));

    final meetings = FakeMeetingRepository([
      Meeting(
        id: Meeting.idFor(organizationId: 'org-1', start: start),
        organizationId: 'org-1',
        organizationName: 'Nexora Robotik',
        requesterId: investorId,
        requesterName: 'Elif Tunca',
        start: start,
        end: start.add(const Duration(minutes: 30)),
        location: 'Online görüşme',
        status: MeetingStatus.confirmed,
        mode: MeetingMode.online,
        roomName: 'oda-1',
      ),
    ]);

    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([exhibitor()]),
      meetings: meetings,
    );
    await completeInvestorOnboarding(tester, auth: auth);

    await tester.tap(find.text('GÖRÜŞMELER'));
    await advance(tester, frames: 12);

    // The half-hour is running, so both the call and the way out of it are on
    // the card — and the rating is not, until somebody ends it.
    expect(find.text('Görüşmeye katıl'), findsOneWidget);
    expect(find.text('Görüşmeyi bitir'), findsOneWidget);
    expect(find.text('Değerlendir'), findsNothing);

    await tester.tap(find.text('Görüşmeyi bitir'));
    await advance(tester, frames: 10);
    await tester.tap(find.widgetWithText(TextButton, 'Bitir'));
    await advance(tester, frames: 20);

    expect(meetings.meetings.single.status, MeetingStatus.completed);
    expect(find.text('Değerlendir'), findsOneWidget);
    expect(find.text('Görüşmeye katıl'), findsNothing);
  });

  testWidgets('a venture is asked without ever showing a grid', (
    tester,
  ) async {
    final meetings = FakeMeetingRepository();

    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      // A venture that declared no hours: open all day, by omission rather than
      // by choice.
      organizations: FakeOrganizationRepository([
        Organization(
          id: 'org-1',
          kind: OrgKind.startup,
          name: 'Nexora Robotik',
          email: 'bilgi@nexora.com',
          address: '',
          description: 'Otonom seyir yazılımı.',
          brand: BrandColor.emerald,
          stage: 'Seed',
          sector: 'Robotik & Otonom Sistemler',
        ),
      ]),
      meetings: meetings,
    );
    await completeInvestorOnboarding(tester, auth: auth);

    showOrgCardSheet(
      tester.element(find.byType(Scaffold).first),
      organizationId: 'org-1',
    );
    await advance(tester, frames: 10);
    await tester.tap(find.text('Toplantı talep et'));
    await advance(tester, frames: 10);

    // No hour picker at all. Every half-hour of the day being open is how the
    // request gets a time, not a question worth asking — a wall of chips with
    // every one of them available is a menu with one dish printed fifty times.
    expect(find.text('SAAT SEÇ'), findsNothing);
    expect(
      find.textContaining('Bu girişim gün boyu görüşmeye açık'),
      findsOneWidget,
    );

    // Straight to sending, and the sender is still told which half-hour they
    // got: they were shown no grid, but they did commit to a time.
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 40);

    expect(meetings.meetings, hasLength(1));
    final sent = meetings.meetings.single;
    expect(sent.organizationId, 'org-1');
    expect(sent.mode, MeetingMode.online);
    // The soonest opening, not the top of the grid: testNow is 08:00, and the
    // 08:00 half-hour is still running, so that is the first one free.
    expect(sent.start, DateTime(testNow.year, testNow.month, testNow.day, 8));
  });

  testWidgets('a half-hour already under way can still be asked for', (
    tester,
  ) async {
    final meetings = FakeMeetingRepository();

    // Ten past eight, with the company open at eight. The half-hour is running
    // but not spent, and at a fair that is exactly when a meeting gets made —
    // the grid used to close a slot the instant it started, throwing away
    // twenty usable minutes of every one.
    final midSlot = testNow.add(const Duration(minutes: 10));

    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([
        exhibitor(slots: const {'08:00'}),
      ]),
      meetings: meetings,
      clock: midSlot,
    );
    await completeInvestorOnboarding(tester, auth: auth);

    showOrgCardSheet(
      tester.element(find.byType(Scaffold).first),
      organizationId: 'org-1',
    );
    await advance(tester, frames: 10);
    await tester.tap(find.text('Toplantı talep et'));
    await advance(tester, frames: 10);

    await tester.tap(find.text('08:00 – 08:30'));
    await advance(tester, frames: 8);
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 40);

    // The controller re-checks the clock independently of the grid, so this
    // also proves the two agree — a screen that offers an hour the controller
    // then refuses is the worst of both rules.
    expect(meetings.meetings, hasLength(1));
    expect(
      meetings.meetings.single.start,
      DateTime(testNow.year, testNow.month, testNow.day, 8),
    );
  });

  testWidgets('a card whose every hour has passed says so instead of asking', (
    tester,
  ) async {
    final meetings = FakeMeetingRepository();

    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      // testNow is 08:00, so a company that only opened the small hours has
      // nothing left today. This is the case that was reported as "the clock is
      // fine but I cannot send a request": since the grid was opened to the
      // whole day, its first chips are the middle of the night, and a company
      // ticking the first ones it saw published hours that were already gone.
      organizations: FakeOrganizationRepository([
        exhibitor(slots: const {'00:00', '00:30', '01:00'}),
      ]),
      meetings: meetings,
    );
    await completeInvestorOnboarding(tester, auth: auth);

    // Reached from the card, deliberately: the picker list refuses the tap on a
    // company with no open hour, but a card has no such guard — which is how
    // this sheet gets opened with nothing to choose.
    showOrgCardSheet(
      tester.element(find.byType(Scaffold).first),
      organizationId: 'org-1',
    );
    await advance(tester, frames: 10);
    await tester.tap(find.text('Toplantı talep et'));
    await advance(tester, frames: 10);

    // Says it on arrival rather than after a failed tap.
    expect(
      find.text('Bu saatlerin hepsi geçti veya doldu — bugün talep gönderilemez.'),
      findsOneWidget,
    );

    // And if the button is pressed anyway, it does not send the visitor hunting
    // for an hour that is not on the screen.
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 10);

    expect(find.text('Bir saat seç.'), findsNothing);
    expect(
      find.text('Kurumun açtığı saatlerin hepsi geçti veya doldu.'),
      findsOneWidget,
    );
    expect(meetings.meetings, isEmpty);
  });
}
