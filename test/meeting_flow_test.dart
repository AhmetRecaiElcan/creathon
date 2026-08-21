import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/domain/availability_slot.dart';
import 'package:creathon/domain/brand_color.dart';
import 'package:creathon/domain/meeting.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
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

  DateTime todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  Meeting requestFor(
    DateTime start, {
    String organizationId = 'org-1',
    String requesterId = 'uid-1',
  }) => Meeting(
    id: Meeting.idFor(organizationId: organizationId, start: start),
    organizationId: organizationId,
    organizationName: 'Nexora Robotik',
    requesterId: requesterId,
    requesterName: 'Elif Tunca',
    requesterEmail: 'elif@example.com',
    start: start,
    end: start.add(const Duration(minutes: 30)),
    location: 'Stand A1',
    status: MeetingStatus.requested,
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
  });
}
