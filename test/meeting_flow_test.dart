import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/meeting.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:creathon/data/meeting_link_repository.dart';
import 'package:creathon/data/meeting_repository.dart';
import 'package:creathon/data/organization_repository.dart';
import 'package:creathon/features/meetings/meetings_controller.dart';
import 'package:creathon/features/meetings/meeting_request_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// The loop the exhibitor and the visitor share: the exhibitor opens hours,
/// the visitor asks for one, and it lands on both their home screens.
void main() {
  setUpAll(loadAppFonts);

  /// The uid `FakeAuthRepository` mints for an address, so a seeded exhibitor
  /// can be owned by the account the test signs in as.
  String uidFor(String email) => 'uid-${email.hashCode}';

  Organization exhibitor({
    String id = 'org-1',
    Set<String> slots = const {'10:00', '14:30'},
  }) => Organization(
    id: id,
    name: 'Nexora Robotik',
    email: 'bilgi@nexora.com',
    address: 'Pendik',
    description: 'Otonom seyir yazılımı.',
    brand: BrandColor.emerald,
    standCode: 'A1',
    availability: [for (final time in slots) AvailabilitySlot(time: time)],
  );

  /// An hour on the day the suite pretends it is. Built off [testNow] rather
  /// than the wall clock, so "10:00" is a fixed distance from "now" whenever
  /// the tests actually run.
  DateTime todayAt(int hour, int minute) =>
      DateTime(testNow.year, testNow.month, testNow.day, hour, minute);

  /// A half-hour still ahead of the pinned clock — the bookable, joinable case.
  DateTime upcoming() => testNow.add(const Duration(hours: 2));

  /// A half-hour behind the pinned clock — the rating case.
  DateTime finished() => testNow.subtract(const Duration(hours: 2));

  Meeting requestFor(
    DateTime start, {
    String organizationId = 'org-1',
    String requesterId = 'uid-1',
    MeetingMode mode = MeetingMode.inPerson,
  }) => Meeting(
    id: Meeting.idFor(organizationId: organizationId, start: start),
    organizationId: organizationId,
    organizationName: 'Nexora Robotik',
    requesterId: requesterId,
    requesterName: 'Elif Tunca',
    requesterEmail: 'elif@example.com',
    start: start,
    end: start.add(const Duration(minutes: 30)),
    location: mode == MeetingMode.online ? 'Online görüşme' : 'Stand A1',
    status: MeetingStatus.requested,
    mode: mode,
  );

  testWidgets('the request sheet offers only the hours the exhibitor opened', (
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
    await completeOnboarding(tester, auth: auth);

    // Opened directly rather than through the card: no shipped role may ask
    // for a meeting yet — that action belongs to the founder and the fund —
    // so the sheet has no entry point in the UI today. What it does once
    // reached is still worth pinning down, because the entry point is what
    // will change when those portfolios land, not this.
    showMeetingRequestSheet(
      tester.element(find.byType(Scaffold).first),
      organization: exhibitor(),
    );
    await advance(tester, frames: 10);

    // Only the two declared hours are offered.
    expect(find.text('SAAT SEÇ'), findsOneWidget);
    expect(find.text('10:00 – 10:30'), findsOneWidget);
    expect(find.text('14:30 – 15:00'), findsOneWidget);
    expect(find.text('11:00 – 11:30'), findsNothing);

    // Sending without choosing must not create anything.
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 8);
    expect(meetings.meetings, isEmpty);
    expect(find.text('Bir saat seç.'), findsOneWidget);

    await tester.tap(find.text('10:00 – 10:30'));
    await advance(tester, frames: 6);
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 10);

    expect(find.text('Talebin gönderildi.'), findsOneWidget);
    expect(meetings.meetings.single.organizationId, 'org-1');
    expect(meetings.meetings.single.startLabel, '10:00');

    // The sheet closes itself, and the meeting is on the home screen.
    await advance(tester, frames: 30);
    expect(find.text('TOPLANTILARIM'), findsOneWidget);
  });

  testWidgets('an hour the visitor already booked is offered as blocked', (
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
    await completeOnboarding(tester, auth: auth);

    // Nothing on the home screen watches the exhibitor list, so the stream has
    // to be subscribed here or reading it cold would return an empty slate.
    final container = containerOf(tester);
    container.listen(organizationsStreamProvider, (_, _) {});
    await advance(tester, frames: 6);

    await meetings.request(
      requestFor(todayAt(10, 0), requesterId: uidFor('elif@example.com')),
    );
    await advance(tester, frames: 10);

    final slots = container.read(organizationSlotsProvider('org-1'));
    final ten = slots.firstWhere((slot) => slot.label == '10:00');

    expect(ten.available, isFalse);
    expect(ten.blockedReason, contains('talebin gönderildi'));
    expect(
      slots.firstWhere((slot) => slot.label == '14:30').available,
      isTrue,
      reason: 'an unrelated hour must stay open',
    );
  });

  testWidgets('an hour that has passed is struck through, not offered', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final meetings = FakeMeetingRepository();

    await pumpApp(
      tester,
      auth: auth,
      // 07:00 is behind the pinned clock, 10:00 is ahead of it.
      organizations: FakeOrganizationRepository([
        exhibitor(slots: const {'07:00', '10:00'}),
      ]),
      meetings: meetings,
    );
    await completeOnboarding(tester, auth: auth);

    final container = containerOf(tester);
    container.listen(organizationsStreamProvider, (_, _) {});
    await advance(tester, frames: 6);

    final slots = container.read(organizationSlotsProvider('org-1'));
    final gone = slots.firstWhere((slot) => slot.label == '07:00');
    final ahead = slots.firstWhere((slot) => slot.label == '10:00');

    // Kept in the list rather than filtered out, so the grid does not appear to
    // shrink through the day — but closed, and saying why.
    expect(gone.isPast, isTrue);
    expect(gone.available, isFalse);
    expect(gone.blockedReason, 'Saati geçti');
    expect(ahead.available, isTrue);

    showMeetingRequestSheet(
      tester.element(find.byType(Scaffold).first),
      organization: exhibitor(slots: const {'07:00', '10:00'}),
    );
    await advance(tester, frames: 10);

    // Both visible, and tapping the gone one selects nothing — so sending is
    // still refused for want of a choice.
    expect(find.text('07:00 – 07:30'), findsOneWidget);
    expect(find.text('10:00 – 10:30'), findsOneWidget);
    await tester.tap(find.text('07:00 – 07:30'));
    await advance(tester, frames: 6);
    await tester.tap(find.widgetWithText(AccentButton, 'Talebi gönder'));
    await advance(tester, frames: 10);

    expect(meetings.meetings, isEmpty);
    expect(find.text('Bir saat seç.'), findsOneWidget);
  });

  testWidgets('the controller refuses a past hour even if the grid offered it', (
    tester,
  ) async {
    // The grid is a rendered list and the clock keeps moving: a sheet left open
    // across the half-hour would otherwise still send. This is the second gate.
    final auth = FakeAuthRepository();
    final meetings = FakeMeetingRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([exhibitor()]),
      meetings: meetings,
    );
    await completeOnboarding(tester, auth: auth);

    final start = todayAt(7, 0);
    await expectLater(
      containerOf(tester).read(meetingsControllerProvider).request(
        organization: exhibitor(),
        start: start,
        end: start.add(const Duration(minutes: 30)),
      ),
      throwsA(
        isA<MeetingFailure>().having(
          (failure) => failure.message,
          'message',
          contains('üzerinden zaman geçti'),
        ),
      ),
    );
    expect(meetings.meetings, isEmpty);
  });

  testWidgets('an exhibitor sees the request on its home and can accept it', (
    tester,
  ) async {
    const email = 'bilgi@nexora.com';
    final orgId = uidFor(email);

    final auth = FakeAuthRepository()..verified = true;
    final meetings = FakeMeetingRepository([
      requestFor(todayAt(10, 0), organizationId: orgId),
    ]);

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([exhibitor(id: orgId)]),
      profiles: FakeProfileStore(
        const UserProfile(
          role: UserRole.corporate,
          firstName: 'Nexora Robotik',
          email: email,
          emailVerified: true,
        ),
      ),
      meetings: meetings,
    );

    await chooseRole(tester, UserRole.corporate);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    expect(find.text('TOPLANTI TALEPLERİ'), findsOneWidget);
    expect(
      find.text('Elif Tunca'),
      findsOneWidget,
      reason: 'the host sees who asked, not their own name',
    );
    // Who, which day, which hour, and in what form — everything the answer
    // depends on, on the card the answer is given from.
    expect(find.text('elif@example.com'), findsOneWidget);
    expect(find.text('Bugün  ·  10:00 – 10:30'), findsOneWidget);
    expect(find.text('Yüz yüze'), findsOneWidget);
    expect(find.text('Onayla'), findsOneWidget);
    expect(find.text('Reddet'), findsOneWidget);

    await tester.tap(find.text('Onayla'));
    await advance(tester, frames: 10);

    expect(meetings.meetings.single.status, MeetingStatus.confirmed);
    expect(
      meetings.meetings.single.roomName,
      isNull,
      reason: 'nobody dials into a booth visit',
    );
  });

  testWidgets('accepting an online request is what creates the room', (
    tester,
  ) async {
    const email = 'bilgi@nexora.com';
    final orgId = uidFor(email);

    final auth = FakeAuthRepository()..verified = true;
    final meetings = FakeMeetingRepository([
      requestFor(
        upcoming(),
        organizationId: orgId,
        mode: MeetingMode.online,
      ),
    ]);
    final links = FakeMeetingLinkRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([exhibitor(id: orgId)]),
      profiles: FakeProfileStore(
        const UserProfile(
          role: UserRole.corporate,
          firstName: 'Nexora Robotik',
          email: email,
          emailVerified: true,
        ),
      ),
      meetings: meetings,
      links: links,
    );

    await chooseRole(tester, UserRole.corporate);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    // Nothing to dial into before the host has agreed to the call, and nothing
    // to ask the signing function for either.
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Görüşmeye katıl'), findsNothing);
    expect(links.asked, isEmpty);

    await tester.tap(find.text('Onayla'));
    await advance(tester, frames: 16);

    final confirmed = meetings.meetings.single;
    expect(confirmed.status, MeetingStatus.confirmed);
    expect(confirmed.roomName, startsWith('takeoff-'));
    expect(confirmed.isJoinable, isTrue);

    // Only now is there a door, and tapping it asks the server to sign one for
    // this meeting. The app never builds the link itself: the private key that
    // would let it is the one thing that must not ship.
    expect(find.text('Görüşmeye katıl'), findsOneWidget);
    await tester.tap(find.text('Görüşmeye katıl'));
    await advance(tester, frames: 12);
    expect(links.asked, [confirmed.id]);
  });

  testWidgets('a refused link says why instead of failing silently', (
    tester,
  ) async {
    const email = 'bilgi@nexora.com';
    final orgId = uidFor(email);

    final auth = FakeAuthRepository()..verified = true;
    final start = upcoming();
    final meetings = FakeMeetingRepository([
      requestFor(
        start,
        organizationId: orgId,
        mode: MeetingMode.online,
      ).copyWith(status: MeetingStatus.confirmed, roomName: 'takeoff-abcdefgh'),
    ]);
    final links = FakeMeetingLinkRepository(
      failure: const JoinLinkFailure('Toplantı henüz onaylanmadı.'),
    );

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([exhibitor(id: orgId)]),
      profiles: FakeProfileStore(
        const UserProfile(
          role: UserRole.corporate,
          firstName: 'Nexora Robotik',
          email: email,
          emailVerified: true,
        ),
      ),
      meetings: meetings,
      links: links,
    );

    await chooseRole(tester, UserRole.corporate);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    await tester.tap(find.text('Görüşmeye katıl'));
    await advance(tester, frames: 16);

    // The function's own words, not a generic apology: it is the only thing
    // that knows which of half a dozen reasons applied.
    expect(find.text('Toplantı henüz onaylanmadı.'), findsOneWidget);
    // And the button is usable again rather than stuck mid-spinner.
    expect(find.text('Görüşmeye katıl'), findsOneWidget);
  });

  /// Signs the given exhibitor in and lands on its home screen, which is where
  /// both a request and a finished meeting show up.
  Future<FakeMeetingFeedbackRepository> signInHost(
    WidgetTester tester, {
    required String email,
    required FakeMeetingRepository meetings,
    required Organization org,
  }) async {
    final auth = FakeAuthRepository()..verified = true;
    final feedback = FakeMeetingFeedbackRepository();

    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository([org]),
      profiles: FakeProfileStore(
        UserProfile(
          role: UserRole.corporate,
          firstName: 'Nexora Robotik',
          email: email,
          emailVerified: true,
        ),
      ),
      meetings: meetings,
      feedback: feedback,
    );

    await chooseRole(tester, UserRole.corporate);
    await tester.tap(find.text('Giriş yap'));
    await advance(tester, frames: 8);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'takeoff2026');
    await tester.tap(find.widgetWithText(AccentButton, 'Giriş yap'));
    await advance(tester, frames: 16);

    return feedback;
  }

  testWidgets('a meeting whose hour has passed asks to be rated, then goes', (
    tester,
  ) async {
    const email = 'bilgi@nexora.com';
    final orgId = uidFor(email);
    final past = finished();

    final meetings = FakeMeetingRepository([
      requestFor(
        past,
        organizationId: orgId,
      ).copyWith(status: MeetingStatus.confirmed),
    ]);

    final feedback = await signInHost(
      tester,
      email: email,
      meetings: meetings,
      org: exhibitor(id: orgId),
    );

    // The hour is behind us, so the card says so on its own — nobody pressed
    // anything to make this happen. And the answer buttons are gone: accepting
    // a meeting that already took place is nonsense.
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.text('Değerlendir'), findsOneWidget);
    expect(find.text('Onayla'), findsNothing);

    await tester.tap(find.text('Değerlendir'));
    await advance(tester, frames: 12);

    expect(find.text('GÖRÜŞME TAMAMLANDI'), findsOneWidget);
    // Nothing preselected, and sending without a star is refused rather than
    // silently recording one.
    expect(find.text('Beş yıldız üzerinden puanla'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(AccentButton, 'Değerlendirmeyi gönder'),
    );
    await advance(tester, frames: 8);
    expect(feedback.entries, isEmpty);
    expect(find.text('Bir yıldız seç.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('4 yıldız'));
    await advance(tester, frames: 6);
    expect(find.text('Verimliydi'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Pilot konuşuldu.');
    await tester.tap(
      find.widgetWithText(AccentButton, 'Değerlendirmeyi gönder'),
    );
    await advance(tester, frames: 30);

    final entry = feedback.entries.single;
    expect(entry.rating, 4);
    expect(entry.note, 'Pilot konuşuldu.');
    expect(entry.authorId, orgId);
    expect(
      entry.counterpartName,
      'Elif Tunca',
      reason: 'the host rated the person across the table, not themselves',
    );

    // The meeting is retired from this account's screens, but the record it
    // rated is still in Firestore — the rating would otherwise point at
    // nothing.
    await advance(tester, frames: 20);
    expect(find.text('Değerlendir'), findsNothing);
    expect(find.text('Tamamlandı'), findsNothing);
    expect(meetings.meetings, hasLength(1));
  });

  testWidgets('an in-person meeting is rated the same way', (tester) async {
    const email = 'bilgi@nexora.com';
    final orgId = uidFor(email);

    final meetings = FakeMeetingRepository([
      requestFor(
        finished(),
        organizationId: orgId,
      ).copyWith(status: MeetingStatus.confirmed),
    ]);

    final feedback = await signInHost(
      tester,
      email: email,
      meetings: meetings,
      org: exhibitor(id: orgId),
    );

    // Nothing about the rating depends on how the two met — a booth visit that
    // is over is as finished as a call that is over.
    expect(find.text('Yüz yüze'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.text('Görüşmeye katıl'), findsNothing);

    await tester.tap(find.text('Değerlendir'));
    await advance(tester, frames: 12);
    await tester.tap(find.bySemanticsLabel('5 yıldız'));
    await advance(tester, frames: 6);
    await tester.tap(
      find.widgetWithText(AccentButton, 'Değerlendirmeyi gönder'),
    );
    await advance(tester, frames: 30);

    expect(feedback.entries.single.rating, 5);
    expect(
      feedback.entries.single.note,
      isNull,
      reason: 'the words are optional; demanding them yields "iyiydi"',
    );
    await advance(tester, frames: 20);
    expect(find.text('Değerlendir'), findsNothing);
  });

  testWidgets('a meeting still ahead of us is not rateable', (tester) async {
    const email = 'bilgi@nexora.com';
    final orgId = uidFor(email);

    final meetings = FakeMeetingRepository([
      requestFor(
        upcoming(),
        organizationId: orgId,
      ).copyWith(status: MeetingStatus.confirmed),
    ]);

    await signInHost(
      tester,
      email: email,
      meetings: meetings,
      org: exhibitor(id: orgId),
    );

    expect(find.text('Onaylandı'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsNothing);
    expect(find.text('Değerlendir'), findsNothing);
  });
}
