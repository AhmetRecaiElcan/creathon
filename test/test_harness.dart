import 'dart:async';

import 'package:creathon/app.dart';
import 'package:creathon/core/util/clock.dart';
import 'package:creathon/data/ai_match_repository.dart';
import 'package:creathon/data/auth_repository.dart';
import 'package:creathon/data/event_repository.dart';
import 'package:creathon/data/invite_repository.dart';
import 'package:creathon/data/meeting_brief_repository.dart';
import 'package:creathon/data/meeting_feedback_repository.dart';
import 'package:creathon/data/meeting_link_repository.dart';
import 'package:creathon/data/meeting_repository.dart';
import 'package:creathon/data/organization_repository.dart';
import 'package:creathon/data/profile_repository.dart';
import 'package:creathon/domain/event_session.dart';
import 'package:creathon/domain/investor_kind.dart';
import 'package:creathon/domain/invite.dart';
import 'package:creathon/domain/match_insight.dart';
import 'package:creathon/domain/meeting.dart';
import 'package:creathon/domain/meeting_brief.dart';
import 'package:creathon/domain/meeting_feedback.dart';
import 'package:creathon/domain/org_kind.dart';
import 'package:creathon/domain/organization.dart';
import 'package:creathon/domain/user_profile.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's real font into the test binding.
///
/// Without this, widget tests measure text with the fallback test font, whose
/// glyphs are square and roughly twice Manrope's width. Layouts that fit
/// comfortably on a device then report overflow in tests, which both hides real
/// problems and invents fake ones.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Manrope')
    ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
  await loader.load();
}

/// The instant every widget test runs at.
///
/// Tests used to read the wall clock, and once the app started closing hours
/// that had gone by, that made them pass in the morning and fail after lunch:
/// an availability grid shuts a slot the moment it passes, and a finished
/// meeting offers a rating instead of a join link. Both are correct behaviour
/// and both are untestable against a clock that keeps moving.
///
/// Eight in the morning of today, so the whole 09:00–17:30 grid is still ahead
/// and `Bugün` is still the right day label. Anything a test needs in the past
/// or the future should be built from this rather than from `DateTime.now()`.
final DateTime testNow = () {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day, 8);
}();

/// Steps the clock forward one short frame at a time.
///
/// The aurora background animates forever, so `pumpAndSettle` never returns. A
/// single long `pump` is not enough either: it advances the clock and fires
/// pending timers, but the frame it produces is built before those timers run,
/// so a navigation triggered by one lands in the router without ever reaching
/// the widget tree.
Future<void> advance(
  WidgetTester tester, {
  int frames = 24,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Auth that never leaves the process.
///
/// Verification is a flag the test flips, which is the whole point: the
/// onboarding flow's contract is "do not advance until the repository says the
/// address is verified", and that is testable without a network.
class FakeAuthRepository implements AuthRepository {
  bool verified = false;
  int sends = 0;
  AuthFailure? failure;

  /// Whether an ID token carrying the verified claim has been minted yet.
  ///
  /// Stands in for the real thing the security rules check. Signing in mints a
  /// fresh token; a restored session starts with the stale one from signup and
  /// only gets a good one once verification is refreshed.
  bool tokenRefreshed = false;

  /// How many times the account was torn down, so a test can assert the
  /// teardown reached Auth and not only Firestore.
  int deletions = 0;

  String? _email;

  @override
  String? get email => _email;

  @override
  String? get uid => _email == null ? null : 'uid-${_email.hashCode}';

  @override
  bool get hasSession => _email != null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (failure != null) throw failure!;
    _email = email;
    tokenRefreshed = true;
  }

  @override
  Future<void> registerAndSendVerification({
    required String email,
    required String password,
  }) async {
    if (failure != null) throw failure!;
    _email = email;
    sends++;
  }

  @override
  Future<bool> refreshVerification() async {
    if (failure != null) throw failure!;
    if (verified) tokenRefreshed = true;
    return verified;
  }

  @override
  Future<void> resendVerification() async {
    if (failure != null) throw failure!;
    sends++;
  }

  @override
  Future<void> signOut() async {
    _email = null;
    verified = false;
    tokenRefreshed = false;
  }

  @override
  Future<void> deleteAccount() async {
    deletions++;
    await signOut();
  }
}

/// In-memory stand-in for the `users/{uid}` document.
class FakeProfileStore implements ProfileStore {
  FakeProfileStore([this.stored, this.tokenGate]);

  /// What [load] hands back — the profile a returning visitor gets restored.
  UserProfile? stored;

  /// When set, reads and writes are refused until this account holds a token
  /// carrying the verified claim — which is what the real security rules do,
  /// and what made a restored session fail before the refresh was moved ahead
  /// of the read.
  final FakeAuthRepository? tokenGate;

  final saves = <UserProfile>[];

  @override
  Future<void> save(UserProfile profile) async {
    _checkToken();
    saves.add(profile);
    stored = profile;
  }

  @override
  Future<UserProfile?> load(String uid) async {
    _checkToken();
    return stored;
  }

  @override
  Future<void> delete(String uid) async {
    _checkToken();
    stored = null;
  }

  void _checkToken() {
    final gate = tokenGate;
    if (gate != null && !gate.tokenRefreshed) {
      throw StateError('permission-denied: token doğrulanmış değil');
    }
  }
}

/// In-memory exhibitor store, including the booth reservation rule.
///
/// The "already taken" branch is reproduced here because it is the one failure
/// the publish step is expected to survive, and it cannot be provoked against
/// a real Firestore from a widget test.
class FakeOrganizationRepository implements OrganizationRepository {
  FakeOrganizationRepository([List<Organization> seed = const []])
    : _organizations = [...seed];

  final List<Organization> _organizations;
  final _changes = StreamController<List<Organization>>.broadcast();

  List<Organization> get organizations => List.unmodifiable(_organizations);

  @override
  Stream<List<Organization>> watchAll() async* {
    yield List.of(_organizations);
    yield* _changes.stream;
  }

  @override
  Future<Organization?> load(String id) async {
    for (final organization in _organizations) {
      if (organization.id == id) return organization;
    }
    return null;
  }

  @override
  Future<void> publish(Organization organization) async {
    final code = organization.standCode;
    if (code == null) {
      // A startup publishes without a booth, so there is nothing to lock and
      // nothing that can have been taken first — the same split the real
      // repository makes.
      if (organization.kind != OrgKind.startup) throw StateError('stand yok');
      await update(organization);
      return;
    }
    final taken = _organizations.any(
      (other) => other.standCode == code && other.id != organization.id,
    );
    if (taken) throw StandTakenFailure(code);
    await update(organization);
  }

  @override
  Future<void> update(Organization organization) async {
    _organizations
      ..removeWhere((other) => other.id == organization.id)
      ..add(organization);
    _changes.add(List.of(_organizations));
  }

  @override
  Future<void> withdraw(Organization organization) async {
    _organizations.removeWhere((other) => other.id == organization.id);
    _changes.add(List.of(_organizations));
  }
}

/// Stands in for the signing function.
///
/// The real link is signed with the video tenant's private key, which is
/// exactly the thing that cannot live in the app — so a widget test can never
/// produce a genuine one. What is testable, and what this records, is that the
/// button asks for a link for the right meeting.
class FakeMeetingLinkRepository implements MeetingLinkRepository {
  FakeMeetingLinkRepository({this.failure});

  /// When set, every request is refused with it — the offline and
  /// not-your-meeting cases the button has to survive.
  final JoinLinkFailure? failure;

  final asked = <String>[];

  @override
  Future<Uri> linkFor(Meeting meeting) async {
    asked.add(meeting.id);
    if (failure != null) throw failure!;
    return Uri.parse('https://8x8.vc/vpaas-test/${meeting.roomName}?jwt=test');
  }
}

/// In-memory rating store, including the one-per-party-per-meeting rule.
class FakeMeetingFeedbackRepository implements MeetingFeedbackRepository {
  FakeMeetingFeedbackRepository([List<MeetingFeedback> seed = const []])
    : _entries = [...seed];

  final List<MeetingFeedback> _entries;
  final _changes = StreamController<List<MeetingFeedback>>.broadcast();

  List<MeetingFeedback> get entries => List.unmodifiable(_entries);

  @override
  Stream<List<MeetingFeedback>> watchByAuthor(String uid) async* {
    yield [for (final e in _entries) if (e.authorId == uid) e];
    yield* _changes.stream.map(
      (all) => [for (final e in all) if (e.authorId == uid) e],
    );
  }

  @override
  Future<void> submit(MeetingFeedback feedback) async {
    if (!MeetingFeedback.isValidRating(feedback.rating)) {
      throw const FeedbackFailure('Bir ile beş yıldız arası bir puan ver.');
    }
    // Create-only, like the rules: a second rating on the same meeting is
    // refused rather than replacing the first.
    if (_entries.any((other) => other.id == feedback.id)) {
      throw const FeedbackFailure('Bu görüşmeyi zaten değerlendirdin.');
    }
    _entries.add(feedback);
    _changes.add(List.of(_entries));
  }
}

/// In-memory meeting store, including the one-request-per-slot rule.
class FakeMeetingRepository implements MeetingRepository {
  FakeMeetingRepository([List<Meeting> seed = const []])
    : _meetings = [...seed];

  final List<Meeting> _meetings;
  final _changes = StreamController<void>.broadcast();

  List<Meeting> get meetings => List.unmodifiable(_meetings);

  @override
  Stream<List<Meeting>> watchForRequester(String uid) =>
      _watch((m) => m.requesterId == uid);

  @override
  Stream<List<Meeting>> watchForOrganization(String orgId) =>
      _watch((m) => m.organizationId == orgId);

  Stream<List<Meeting>> _watch(bool Function(Meeting) matches) async* {
    yield _matching(matches);
    await for (final _ in _changes.stream) {
      yield _matching(matches);
    }
  }

  List<Meeting> _matching(bool Function(Meeting) matches) {
    final found = _meetings.where(matches).toList();
    found.sort((a, b) => a.start.compareTo(b.start));
    return found;
  }

  @override
  Future<void> request(Meeting meeting) async {
    if (_meetings.any((other) => other.id == meeting.id)) {
      throw SlotTakenFailure(meeting.startLabel);
    }
    _meetings.add(meeting);
    _changes.add(null);
  }

  @override
  Future<void> respond(
    Meeting meeting,
    MeetingStatus status, {
    String? roomName,
  }) async {
    _meetings.removeWhere((other) => other.id == meeting.id);
    // Declining removes the record so the slot opens back up, exactly as the
    // real repository does.
    if (status != MeetingStatus.declined) {
      _meetings.add(meeting.copyWith(status: status, roomName: roomName));
    }
    _changes.add(null);
  }

  /// Set to make [finish] throw, so the card's failure path can be driven.
  bool finishFails = false;

  @override
  Future<void> finish(Meeting meeting) async {
    if (finishFails) throw const MeetingFailure('Görüşme bitirilemedi.');
    _meetings.removeWhere((other) => other.id == meeting.id);
    _meetings.add(meeting.copyWith(status: MeetingStatus.completed));
    _changes.add(null);
  }
}

/// A session anchored to today, so `isLiveAt` behaves the same whenever the
/// suite runs.
EventSession testSession({
  required String id,
  required String title,
  required int hour,
  List<String> sectors = const [],
}) {
  final now = DateTime.now();
  return EventSession(
    id: id,
    title: title,
    speaker: 'Test Konuşmacı',
    org: 'T3 Vakfı',
    kind: SessionKind.panel,
    venue: 'Ana Sahne',
    start: DateTime(now.year, now.month, now.day, hour),
    end: DateTime(now.year, now.month, now.day, hour + 1),
    sectors: sectors,
  );
}

/// The guest list, in memory.
///
/// Left out of [pumpApp] by default on purpose: with no override the real store
/// runs, `firebaseReady` is false under `flutter test`, and every lookup comes
/// back [InviteUnknown] — so the admission gate stays open and the tests that
/// predate it keep signing accounts up. Only a test that is *about* admission
/// hands one of these in.
class FakeInviteStore implements InviteStore {
  FakeInviteStore({this.roles = const {}, this.readable = true});

  /// Address (already lower-cased) to the audience it was admitted as.
  final Map<String, UserRole> roles;

  /// False stands in for a list that could not be read at all — the case that
  /// must let a signup through rather than refuse it.
  final bool readable;

  final List<String> lookups = [];

  @override
  Future<InviteLookup> find(String email) async {
    final id = Invite.idFor(email);
    lookups.add(id);
    if (!readable) return const InviteUnknown();
    final role = roles[id];
    return role == null ? const InviteMissing() : InviteFound(role);
  }
}

/// A briefing the test writes itself, standing in for Gemini.
///
/// Either a brief or a failure, never both: the sheet has exactly two outcomes
/// and both are worth a test — one renders three questions, the other renders
/// the function's own complaint and a way to ask again.
class FakeMeetingBriefRepository implements MeetingBriefRepository {
  FakeMeetingBriefRepository({
    this.brief,
    this.failure,
    this.model = 'gemini-2.5-flash-lite',
  });

  final MeetingBrief? brief;
  final BriefFailure? failure;
  final String model;

  /// Which meetings were briefed, so a test can assert the sheet asked about
  /// the meeting it was opened from and not some other one.
  final requested = <String>[];

  @override
  Future<BriefResult> briefFor(Meeting meeting) async {
    requested.add(meeting.id);
    final refusal = failure;
    if (refusal != null) throw refusal;
    return BriefResult(brief: brief!, model: model, cached: false);
  }
}

/// A ranking the test writes itself, standing in for Gemini.
///
/// The point of overriding at this seam rather than mocking the callable is
/// that everything above it is the code that ships: the merge with
/// [CardMatcher], the reordering, the percentage on the badge and the sentence
/// under the name all run for real against a verdict the test controls.
class FakeAiMatchRepository implements AiMatchRepository {
  FakeAiMatchRepository(this.verdicts, {this.model = 'gemini-2.5-flash-lite'});

  final List<AiMatch> verdicts;
  final String model;

  /// How many times the ranking was asked for, so a test can assert the model
  /// is not being re-run on every rebuild.
  int calls = 0;

  @override
  Future<AiRanking> rank() async {
    calls++;
    return AiRanking(
      matches: {for (final verdict in verdicts) verdict.orgId: verdict},
      model: model,
      cached: false,
    );
  }
}

Future<void> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeProfileStore? profiles,
  FakeOrganizationRepository? organizations,
  FakeMeetingRepository? meetings,
  FakeMeetingLinkRepository? links,
  FakeMeetingFeedbackRepository? feedback,
  FakeMeetingBriefRepository? briefs,
  FakeInviteStore? invites,
  /// The model's ranking. Defaults to [OfflineAiMatchRepository], so a test
  /// that does not care about the AI path gets the deterministic scorer and no
  /// pending future — which is also exactly what a demo with no key gets.
  AiMatchRepository? aiMatches,
  List<EventSession> sessions = const [],
  /// The instant the app runs at. Defaults to [testNow]; a test pins something
  /// else when the behaviour under test is about *where inside* a half-hour the
  /// clock is, which testNow's tidy 08:00 cannot express.
  DateTime? clock,
}) async {
  // A realistic phone viewport: on the default 800x600 test surface the lower
  // role cards fall outside the viewport, where they cannot be tapped.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
        if (profiles != null)
          profileRepositoryProvider.overrideWithValue(profiles),
        if (organizations != null)
          organizationRepositoryProvider.overrideWithValue(organizations),
        if (meetings != null)
          meetingRepositoryProvider.overrideWithValue(meetings),
        if (links != null)
          meetingLinkRepositoryProvider.overrideWithValue(links),
        if (feedback != null)
          meetingFeedbackRepositoryProvider.overrideWithValue(feedback),
        if (briefs != null)
          meetingBriefRepositoryProvider.overrideWithValue(briefs),
        if (invites != null) inviteStoreProvider.overrideWithValue(invites),
        aiMatchRepositoryProvider.overrideWithValue(
          aiMatches ?? const OfflineAiMatchRepository(),
        ),
        eventsStreamProvider.overrideWith((ref) => Stream.value(sessions)),
        // Pinned, not ticking: see [testNow].
        clockProvider.overrideWithValue(clock ?? testNow),
      ],
      child: const TakeOffApp(),
    ),
  );
  await advance(tester);
}

/// Scrolls the first scrollable until [finder] is on screen and tappable.
///
/// Two separate problems have to be solved here. `ListView` only creates
/// elements near the viewport, so a widget further down the page is genuinely
/// absent from the tree and `skipOffstage` cannot reach it — hence the drags.
/// But existing in the tree is not enough either: a widget in the cache area
/// below the fold has a centre outside the screen, and `tester.tap` on it
/// silently dispatches the pointer to whatever is actually there — hence the
/// final `ensureVisible`.
///
/// `scrollUntilVisible` is unusable in this app because it settles the tree, and
/// the aurora animation never settles.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  int maxDrags = 14,
  double delta = -320,
}) async {
  for (var i = 0; i < maxDrags && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, delta));
    await advance(tester, frames: 4);
  }
  if (finder.evaluate().isEmpty) return;

  await tester.ensureVisible(finder.first);
  await advance(tester, frames: 6);
}

Future<void> chooseRole(WidgetTester tester, UserRole role) async {
  await tester.tap(find.text(role.label));
  await advance(tester);
}

/// Fills in the identity step and submits it, leaving the tester on whichever
/// step the auth repository's answer leads to.
Future<void> submitIdentity(
  WidgetTester tester, {
  String firstName = 'Elif',
  String lastName = 'Tunca',
  String email = 'elif@example.com',
  String password = 'takeoff2026',
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), firstName);
  await tester.enterText(fields.at(1), lastName);
  await tester.enterText(fields.at(2), email);
  await tester.enterText(fields.at(3), password);
  await advance(tester, frames: 4);

  await tester.tap(find.text('Hesabımı oluştur'));
  await advance(tester, frames: 10);
}

/// Runs the whole visitor signup — identity, verification, interests — and
/// leaves the tester on the home tab.
Future<void> completeOnboarding(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  List<String> sectors = const ['Yapay Zekâ'],
}) async {
  await chooseRole(tester, UserRole.visitor);
  await submitIdentity(tester);

  // The link in the mail gets followed: the next poll finds it verified.
  auth.verified = true;
  await tester.tap(find.text('Doğrulamayı kontrol et'));
  await advance(tester, frames: 10);

  for (final sector in sectors) {
    await tester.tap(find.text(sector));
    await advance(tester, frames: 6);
  }
  await tester.tap(find.text('Devam'));
  await advance(tester, frames: 10);

  await tester.tap(find.text('Take Off\'a başla'));
  await advance(tester);
}

/// Runs the whole founder signup — identity, verification, the venture, its
/// stage and field, the optional links — and publishes the card, leaving the
/// tester on the home tab.
Future<void> completeEntrepreneurOnboarding(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  String venture = 'Nexora Robotik',
  String pitch = 'İnsansız kara araçları için otonom seyir yazılımı.',
  String contactEmail = 'iletisim@nexora.com',
  String stage = 'Seed',
  String sector = 'Yapay Zekâ',
  String market = 'Ulusal',
}) async {
  await chooseRole(tester, UserRole.entrepreneur);
  await submitIdentity(tester);

  auth.verified = true;
  await tester.tap(find.text('Doğrulamayı kontrol et'));
  await advance(tester, frames: 10);

  // The venture step: name, pitch and the public address.
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), venture);
  await tester.enterText(fields.at(1), pitch);
  await tester.enterText(fields.at(2), contactEmail);
  await advance(tester, frames: 4);
  await tester.tap(find.text('Devam'));
  await advance(tester, frames: 10);

  // Stage, field and target market — all three required before the step passes.
  await tester.tap(find.text(stage));
  await advance(tester, frames: 6);
  await scrollTo(tester, find.text(sector));
  await tester.tap(find.text(sector));
  await advance(tester, frames: 6);
  await scrollTo(tester, find.text(market));
  await tester.tap(find.text(market));
  await advance(tester, frames: 6);
  await tester.tap(find.text('Devam'));
  await advance(tester, frames: 10);

  // Contact channels are all optional.
  await tester.tap(find.text('Devam'));
  await advance(tester, frames: 10);

  await tester.tap(find.text('Kartı yayına al'));
  await advance(tester, frames: 14);
}

/// Runs the whole investor signup — identity, verification, the fund and its
/// kind, then the thesis — and leaves the tester on the home tab.
Future<void> completeInvestorOnboarding(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  String company = 'Ada Ventures',
  InvestorKind kind = InvestorKind.angel,
  List<String> sectors = const ['Yapay Zekâ'],
  List<String> stages = const ['Seed'],
  List<String> markets = const ['Ulusal'],
}) async {
  await chooseRole(tester, UserRole.investor);
  await submitIdentity(tester);

  auth.verified = true;
  await tester.tap(find.text('Doğrulamayı kontrol et'));
  await advance(tester, frames: 10);

  // The investor step: one field and one choice.
  await tester.enterText(find.byType(TextField).first, company);
  await advance(tester, frames: 4);
  await tester.tap(find.text(kind.label));
  await advance(tester, frames: 6);
  await tester.tap(find.text('Devam'));
  await advance(tester, frames: 10);

  for (final sector in sectors) {
    await tester.tap(find.text(sector));
    await advance(tester, frames: 6);
  }
  await tester.tap(find.text('Devam'));
  await advance(tester, frames: 10);

  // The screening criteria: which levels, and how far a company has to reach.
  for (final stage in stages) {
    await scrollTo(tester, find.text(stage));
    await tester.tap(find.text(stage));
    await advance(tester, frames: 6);
  }
  for (final market in markets) {
    await scrollTo(tester, find.text(market));
    await tester.tap(find.text(market));
    await advance(tester, frames: 6);
  }
  await tester.tap(find.text('Devam'));
  await advance(tester, frames: 10);

  await tester.tap(find.text('Take Off\'a başla'));
  await advance(tester);
}

/// The Riverpod container backing the running app, for asserting on state that
/// is not visible on screen.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TakeOffApp)));
