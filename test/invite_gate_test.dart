import 'package:creathon/domain/invite.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// Admission: only an address the organiser put on the guest list may register,
/// and only through the door it was admitted for.
///
/// These tests cover the *message*, which is the part a rule cannot produce.
/// The enforcement lives in `firebase/firestore.rules` — the `users/{uid}`
/// create rule compares the role being written against the guest list — and
/// nothing in a widget test can reach it. So each case here is about what the
/// person in front of the screen is told to do next.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('an address admitted as a visitor registers as a visitor', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final invites = FakeInviteStore(
      roles: {'elif@example.com': UserRole.visitor},
    );
    await pumpApp(tester, auth: auth, invites: invites);
    await chooseRole(tester, UserRole.visitor);
    await submitIdentity(tester, email: 'elif@example.com');

    // Straight on to the verification step: nothing was refused, and the
    // session was not thrown away.
    expect(find.text('E-postanı doğrula.'), findsOneWidget);
    expect(auth.hasSession, isTrue);
  });

  testWidgets('an address admitted as a visitor is refused at the investor door', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final invites = FakeInviteStore(
      roles: {'elif@example.com': UserRole.visitor},
    );
    await pumpApp(tester, auth: auth, invites: invites);
    await chooseRole(tester, UserRole.investor);
    await submitIdentity(tester, email: 'elif@example.com');

    // The message has to name the door that would work. "Not allowed" alone
    // leaves the guest guessing between three remaining audiences.
    expect(
      find.textContaining('Ziyaretçi olarak tanımlı'),
      findsOneWidget,
    );
    // A refused attempt must not leave the device holding a session it is not
    // allowed to use — the same contract the role-mismatch path keeps.
    expect(auth.hasSession, isFalse);
  });

  testWidgets('an address that is on no list at all is refused', (tester) async {
    final auth = FakeAuthRepository();
    final invites = FakeInviteStore(roles: const {});
    await pumpApp(tester, auth: auth, invites: invites);
    await chooseRole(tester, UserRole.visitor);
    await submitIdentity(tester, email: 'yabanci@example.com');

    expect(find.textContaining('etkinliğe tanımlı değil'), findsOneWidget);
    expect(auth.hasSession, isFalse);
  });

  testWidgets('capitals in either place still match', (tester) async {
    final auth = FakeAuthRepository();
    // The organiser typed it lower-case in the panel; the guest types it with a
    // capital on their phone. Both go through Invite.idFor, so they meet.
    final invites = FakeInviteStore(
      roles: {'elif@example.com': UserRole.visitor},
    );
    await pumpApp(tester, auth: auth, invites: invites);
    await chooseRole(tester, UserRole.visitor);
    await submitIdentity(tester, email: '  Elif@Example.com ');

    expect(find.text('E-postanı doğrula.'), findsOneWidget);
    expect(invites.lookups, ['elif@example.com']);
  });

  testWidgets('a guest list that cannot be read does not lock anyone out', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    // Firebase down, offline, or rules not published yet. Refusing here would
    // shut the whole event out of its own app over a network blip, and the
    // Firestore rule still has the last word on the write that follows.
    final invites = FakeInviteStore(readable: false);
    await pumpApp(tester, auth: auth, invites: invites);
    await chooseRole(tester, UserRole.visitor);
    await submitIdentity(tester, email: 'elif@example.com');

    expect(find.text('E-postanı doğrula.'), findsOneWidget);
    expect(auth.hasSession, isTrue);
  });

  test('the document id is the address, folded once', () {
    // Every comparison in the system — panel write, phone read, Firestore rule —
    // goes through this one function. A second opinion about casing anywhere
    // would refuse an invited guest at the door.
    expect(Invite.idFor('  Elif@Example.COM '), 'elif@example.com');
    expect(Invite.idFor(''), '');
  });

  test('a row saved without an audience admits its guest to any of them', () {
    // The organiser's half-filled form is not the guest's fault, so an absent
    // role must not read as a refusal.
    final invite = Invite.fromMap(const {'email': 'a@b.com'}, id: 'a@b.com');
    expect(invite.role, isNull);
  });
}
