import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/select_chip.dart';
import '../../core/widgets/step_page.dart';
import '../../data/auth_repository.dart';
import '../../data/invite_repository.dart';
import '../../data/organization_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/brand_color.dart';
import '../../domain/investor_kind.dart';
import '../../domain/invite.dart';
import '../../domain/org_kind.dart';
import '../../domain/organization.dart';
import '../../domain/taxonomy.dart';
import '../../domain/user_profile.dart';
import '../../domain/user_role.dart';
import '../matching/widgets/match_preview.dart';
import '../organization/org_setup_pages.dart';
import '../organization/organization_controller.dart';
import '../organization/venture_setup_pages.dart';
import '../profile/profile_controller.dart';

/// Signup and setup in one flow: who you are, proof that the address is yours,
/// and what you came for.
///
/// The identity step replaces the old goals questionnaire. A visitor's account
/// is what the agenda, the wallpaper and the stand notes hang off, so it has to
/// exist before the app can promise to remember anything.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Every question either flow can ask. Which of them appear, and in what
/// order, is decided per role by [_OnboardingScreenState._stepsFor].
enum _Step {
  identity,
  verify,
  investorProfile,
  investorFocus,
  sectors,
  orgDetails,
  orgLinks,
  standPick,
  ventureDetails,
  ventureFocus,
  summary,
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// The steps this run will ask, fixed at entry.
  ///
  /// The role cannot change without leaving the flow — backing out of the
  /// first step resets it — so resolving this once keeps every index stable.
  late final List<_Step> _steps;

  static List<_Step> _stepsFor(UserRole? role) => switch (role) {
    // An exhibitor's setup is longer because its output is public: a card
    // strangers will read and a booth nobody else can then take.
    UserRole.corporate => const [
      _Step.identity,
      _Step.verify,
      _Step.orgDetails,
      _Step.orgLinks,
      _Step.standPick,
      _Step.summary,
    ],
    // A founder publishes a card like the exhibitor does, but without a booth
    // to claim — so the plan step drops out and the stage takes its place. No
    // separate interests step either: the venture's own field is the answer,
    // and asking the same question twice is how forms lose people.
    UserRole.entrepreneur => const [
      _Step.identity,
      _Step.verify,
      _Step.ventureDetails,
      _Step.ventureFocus,
      _Step.orgLinks,
      _Step.summary,
    ],
    // An investor answers one question a visitor never gets asked: who they
    // invest for. It sits before the sectors step because the fund is what
    // gives that thesis a name.
    UserRole.investor => const [
      _Step.identity,
      _Step.verify,
      _Step.investorProfile,
      _Step.sectors,
      // The thesis is asked in two halves on purpose: the field is what the
      // investor calls themselves, the level and the reach are what they screen
      // on. Both feed the ranking on their home screen.
      _Step.investorFocus,
      _Step.summary,
    ],
    _ => const [_Step.identity, _Step.verify, _Step.sectors, _Step.summary],
  };

  /// How often the app asks Firebase whether the link in the mail has been
  /// followed. Short enough that following it feels instant, long enough not
  /// to hammer the endpoint while the user hunts through their inbox.
  static const _pollInterval = Duration(seconds: 4);

  final _pageController = PageController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Exhibitor fields. Held here rather than in the organisation controller so
  // a half-typed address is not published on every keystroke.
  //
  // The founder shares most of them — the pitch is the description, the public
  // address is the contact e-mail — and adds only the venture's own name, which
  // the exhibitor types on the identity step instead.
  final _ventureName = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _contactEmail = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _linkedin = TextEditingController();
  final _phone = TextEditingController();

  /// Investor fields. The fund's name is typed, the kind is picked, and neither
  /// reaches the profile until the step is submitted.
  final _company = TextEditingController();
  InvestorKind? _investorKind;

  int _index = 0;
  bool _busy = false;

  /// Returning visitors land on the same first step, flipped into a two-field
  /// sign-in. Without it a second visit means "create account" on an address
  /// that already has one — the flow's sharpest edge.
  bool _signInMode = false;

  String? _error;
  String? _notice;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Re-entering the flow after a back-out should not present empty fields
    // when the profile already knows the answers.
    final profile = ref.read(profileProvider);
    _steps = _stepsFor(profile.role);
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _email.text = profile.email;
    _company.text = profile.companyName;
    _investorKind = profile.investorKind;

    final organization = ref.read(organizationProvider).organization;
    if (organization != null) _fillOrgFields(organization);
  }

  void _fillOrgFields(Organization organization) {
    _ventureName.text = organization.name;
    _address.text = organization.address;
    _description.text = organization.description;
    _contactEmail.text = organization.email;
    _website.text = organization.website ?? '';
    _instagram.text = organization.instagram ?? '';
    _linkedin.text = organization.linkedin ?? '';
    _phone.text = organization.phone ?? '';
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pageController.dispose();
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _password,
      _address,
      _description,
      _contactEmail,
      _website,
      _instagram,
      _linkedin,
      _phone,
      _company,
      _ventureName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  _Step get _step => _steps[math.min(_index, _steps.length - 1)];

  /// Moves to a step. [clearError] exists for the one case where the move is
  /// itself the consequence of the error — losing a booth sends the user back
  /// to the plan, and the reason has to survive the trip.
  void _goTo(int index, {bool clearError = true}) {
    setState(() {
      _index = index;
      if (clearError) _error = null;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) {
      // Leaving the flow entirely: clear the role so the welcome screen's
      // aurora returns to showing all four audiences.
      _poll?.cancel();
      ref.read(profileProvider.notifier).reset();
      context.go('/');
      return;
    }
    // Stepping back off the verification screen would leave the poller running
    // against an account the user is about to re-create under another address.
    _poll?.cancel();
    _goTo(_index - 1);
  }

  bool get _isCorporate =>
      ref.read(profileProvider).role == UserRole.corporate;

  bool get _isInvestor => ref.read(profileProvider).role == UserRole.investor;

  bool get _isEntrepreneur =>
      ref.read(profileProvider).role == UserRole.entrepreneur;

  /// Whether this run ends by publishing a card rather than by entering the app.
  bool get _publishesCard =>
      ref.read(profileProvider).role?.publishesCard ?? false;

  /// The step after verification: interests for a visitor, the exhibitor's own
  /// details for a company.
  void _goPastVerification() =>
      _goTo(_steps.indexOf(_Step.verify) + 1);

  Future<void> _submitIdentity() async {
    final role = ref.read(profileProvider).role;
    final corporate = role == UserRole.corporate;
    // An exhibitor types one name — the organisation's. The second field is
    // not on screen for them, so it must not be part of the check.
    final first = _firstName.text.trim();
    final last = corporate ? '' : _lastName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    final complaint = corporate
        ? _validateOrgIdentity(name: first, email: email, password: password)
        : _validateIdentity(
            first: first,
            last: last,
            email: email,
            password: password,
          );
    if (complaint != null) {
      setState(() => _error = complaint);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final controller = ref.read(profileProvider.notifier);
    controller.setIdentity(firstName: first, lastName: last, email: email);

    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.registerAndSendVerification(email: email, password: password);
      if (!mounted) return;

      // An address that was already verified in an earlier session should not
      // send the user back to their inbox for nothing.
      final already = await auth.refreshVerification();
      if (!mounted) return;

      // "Create account" on an address that already has one signs into it
      // instead, so this path can land on somebody else's audience just as
      // easily as the sign-in path can.
      final uid = auth.uid;
      if (uid != null) {
        final stored = await ref.read(profileRepositoryProvider).load(uid);
        if (!mounted) return;
        if (await _rejectRoleMismatch(stored?.role, role)) return;
        // The guest list gates new accounts only. An account that already
        // carries a profile was admitted before this list existed, and its
        // meetings, card and booth are all keyed to that uid — shutting it out
        // now would strand every one of them.
        if (stored == null && await _rejectUninvited(email, role)) return;
      }

      // Both card-publishing roles open a draft here, because the card is keyed
      // by the uid and there was nothing to draft before the account existed.
      // The exhibitor already typed its name on this step; the founder types
      // the venture's name on the next one, so the draft starts unnamed.
      if (role?.publishesCard ?? false) {
        _beginOrganization(
          uid: auth.uid,
          name: corporate ? first : '',
          email: email,
          kind: corporate ? OrgKind.corporate : OrgKind.startup,
        );
      }

      if (already) {
        controller.markVerified(uid: auth.uid);
        setState(() => _busy = false);
        _goPastVerification();
        return;
      }

      setState(() {
        _busy = false;
        _notice = null;
      });
      _goTo(_steps.indexOf(_Step.verify));
      _startPolling();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  /// Opens the card draft once the account exists — the organisation is keyed
  /// by the uid, so there is nothing to draft before then.
  void _beginOrganization({
    required String? uid,
    required String name,
    required String email,
    OrgKind kind = OrgKind.corporate,
  }) {
    if (uid == null) return;
    final orgController = ref.read(organizationProvider.notifier);
    if (ref.read(organizationProvider).organization != null) return;
    orgController.start(id: uid, name: name, email: email, kind: kind);
    // The login address is the sensible default for the public one; the
    // exhibitor can replace it on the next step.
    if (_contactEmail.text.trim().isEmpty) _contactEmail.text = email;
  }

  /// Signs an existing account in and resumes wherever that account left off:
  /// straight into the app when it is complete, at the interests step when the
  /// first attempt stopped there, at the verification screen when the link in
  /// the mail was never followed.
  Future<void> _submitSignIn() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Geçerli bir e-posta adresi gir.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Şifreni gir.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final controller = ref.read(profileProvider.notifier);
    final role = ref.read(profileProvider).role;

    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.signIn(email: email, password: password);
      final verified = await auth.refreshVerification();
      final uid = auth.uid;
      final stored = uid == null
          ? null
          : await ref.read(profileRepositoryProvider).load(uid);
      if (!mounted) return;

      if (stored == null) {
        // The account exists but never got a profile document — a signup
        // abandoned before the interests step. Finish it rather than pretend
        // there is nothing to fill in.
        setState(() {
          _busy = false;
          _signInMode = false;
          _notice = null;
          _error = 'Profilin yarım kalmış. Adını ve soyadını tamamlayalım.';
        });
        return;
      }

      if (await _rejectRoleMismatch(stored.role, role)) return;
      if (!mounted) return;

      controller.hydrate(
        stored.copyWith(
          uid: uid,
          email: email,
          emailVerified: verified,
          role: stored.role ?? role,
        ),
      );
      _firstName.text = stored.firstName;
      _lastName.text = stored.lastName;
      // An investor's fund and kind come back with the account too. Without
      // this, a sign-in that resumes at the investor step would present an
      // empty form for answers the profile already holds — and re-typing them
      // is the fastest way to end up with two different fund names.
      _company.text = stored.companyName;
      _investorKind = stored.investorKind;

      // An exhibitor's account is only half the record; the card lives in its
      // own document and decides where this sign-in lands.
      final resumedRole = stored.role ?? role;
      Organization? organization;
      if ((resumedRole?.publishesCard ?? false) && uid != null) {
        organization = await ref
            .read(organizationRepositoryProvider)
            .load(uid);
        if (!mounted) return;
        if (organization != null) {
          ref.read(organizationProvider.notifier).hydrate(organization);
          _fillOrgFields(organization);
        } else {
          final corporate = resumedRole == UserRole.corporate;
          _beginOrganization(
            uid: uid,
            name: corporate ? stored.firstName : '',
            email: email,
            kind: corporate ? OrgKind.corporate : OrgKind.startup,
          );
        }
      }

      setState(() => _busy = false);

      if (!verified) {
        _goTo(_steps.indexOf(_Step.verify));
        _startPolling();
        return;
      }
      if (ref.read(onboardedProvider)) {
        context.go('/home');
        return;
      }
      // Something is still missing; drop the user on the first step that can
      // collect it rather than on a screen that would refuse to continue.
      _goPastVerification();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  /// Refuses an address that already belongs to a different audience.
  ///
  /// One account is one role: the profile document, the organisation document
  /// and the meetings collection are all keyed by the same uid, so letting a
  /// visitor's address in through the exhibitor door would build a company on
  /// top of their profile. Signing out matters as much as the message — a
  /// refused attempt must not leave the device holding a session it is not
  /// allowed to use.
  Future<bool> _rejectRoleMismatch(UserRole? stored, UserRole? chosen) async {
    if (stored == null || chosen == null || stored == chosen) return false;

    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return true;
    setState(() {
      _busy = false;
      _notice = null;
      _error =
          'Bu e-posta ${stored.label.toLowerCase()} hesabına ait. '
          'Geri dön ve ${stored.label} olarak devam et.';
    });
    return true;
  }

  /// Refuses an address the organiser never admitted, and an address admitted
  /// as a different audience.
  ///
  /// This check is for the *message*, not for the security: the rule on
  /// `users/{uid}` is what actually refuses to write a profile whose role the
  /// guest list did not grant, and it cannot be talked out of it from a client.
  /// What that rule cannot do is explain itself — it fails a fire-and-forget
  /// write and the app carries on believing the account is real. So the check
  /// runs here too, where there is a screen to say which door to use.
  ///
  /// Which is also why an unreadable guest list lets the attempt through: a
  /// dropped connection must not read as "not invited" and lock out the event.
  /// The rule still has the last word either way.
  Future<bool> _rejectUninvited(String email, UserRole? chosen) async {
    final lookup = await ref.read(inviteStoreProvider).find(email);
    if (!mounted) return false;

    final String complaint;
    switch (lookup) {
      case InviteUnknown():
        return false;
      case InviteFound(role: final invited):
        // A row saved without an audience admits its guest to any of them —
        // the organiser's half-filled form is not the guest's problem.
        if (invited == null || invited == chosen) return false;
        complaint =
            'Bu e-posta ${invited.label} olarak tanımlı. '
            'Geri dön ve ${invited.label} olarak kayıt ol.';
      case InviteMissing():
        complaint =
            'Bu e-posta adresi etkinliğe tanımlı değil. '
            'Kayıt için etkinlik ekibiyle iletişime geç.';
    }

    // Same reason as the role-mismatch path: a refused attempt must not leave
    // the device holding a session it is not allowed to use.
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return true;
    setState(() {
      _busy = false;
      _notice = null;
      _error = complaint;
    });
    return true;
  }

  void _toggleMode() {
    setState(() {
      _signInMode = !_signInMode;
      _error = null;
      _notice = null;
    });
  }

  // Deliberately loose: the authoritative check is whether the verification
  // mail arrives, and a strict pattern only rejects valid unusual addresses.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? _validateIdentity({
    required String first,
    required String last,
    required String email,
    required String password,
  }) {
    if (first.isEmpty || last.isEmpty) return 'Adını ve soyadını gir.';
    if (!_emailPattern.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (password.length < 6) return 'Şifre en az 6 karakter olmalı.';
    return null;
  }

  static String? _validateOrgIdentity({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.isEmpty) return 'Kurumunun adını gir.';
    if (!_emailPattern.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (password.length < 6) return 'Şifre en az 6 karakter olmalı.';
    return null;
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => _checkVerification());
  }

  Future<void> _checkVerification({bool manual = false}) async {
    if (_busy) return;
    if (manual) setState(() => _busy = true);

    try {
      final auth = ref.read(authRepositoryProvider);
      final verified = await auth.refreshVerification();
      if (!mounted) return;

      if (verified) {
        _poll?.cancel();
        ref.read(profileProvider.notifier).markVerified(uid: auth.uid);
        setState(() {
          _busy = false;
          _error = null;
          _notice = null;
        });
        _goPastVerification();
        return;
      }

      if (manual) {
        setState(() {
          _busy = false;
          _error = 'Henüz doğrulanmamış. Gelen kutunu ve spam klasörünü kontrol et.';
        });
      }
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (manual) _error = failure.message;
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = 'Doğrulama bağlantısı yeniden gönderildi.';
      });
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  void _onPrimaryAction() {
    switch (_step) {
      case _Step.identity:
        _signInMode ? _submitSignIn() : _submitIdentity();
      case _Step.verify:
        _checkVerification(manual: true);
      case _Step.investorProfile:
        _submitInvestorProfile();
      case _Step.investorFocus:
      case _Step.sectors:
        _goTo(_index + 1);
      case _Step.orgDetails:
        _submitOrgDetails();
      case _Step.orgLinks:
        _submitOrgLinks();
      case _Step.standPick:
        _goTo(_index + 1);
      case _Step.ventureDetails:
        _submitVentureDetails();
      case _Step.ventureFocus:
        _submitVentureFocus();
      case _Step.summary:
        _publishesCard ? _publish() : context.go('/home');
    }
  }

  void _submitVentureDetails() {
    final name = _ventureName.text.trim();
    final pitch = _description.text.trim();
    final contact = _contactEmail.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Girişiminin adını gir.');
      return;
    }
    if (pitch.isEmpty) {
      setState(() => _error = 'Girişiminin ne yaptığını kısaca yaz.');
      return;
    }
    if (!_emailPattern.hasMatch(contact)) {
      setState(() => _error = 'Geçerli bir iletişim e-postası gir.');
      return;
    }

    ref.read(organizationProvider.notifier).setVenture(
      name: name,
      description: pitch,
      email: contact,
    );
    _goTo(_index + 1);
  }

  /// The venture's field is also the founder's own interest, so it is mirrored
  /// onto the profile: that is what orders the programme on their home screen,
  /// and it would be the same answer to a question asked twice.
  void _submitVentureFocus() {
    final organization = ref.read(organizationProvider).organization;
    final sector = organization?.sectorLabel;
    if (sector != null) {
      ref.read(profileProvider.notifier).setSectors({sector});
    }
    _goTo(_index + 1);
  }

  void _submitInvestorProfile() {
    final company = _company.text.trim();
    final kind = _investorKind;

    if (company.isEmpty) {
      setState(() => _error = 'Yatırım yaptığın şirketin ya da fonun adını gir.');
      return;
    }
    if (kind == null) {
      setState(() => _error = 'Melek mi kurumsal mı, birini seç.');
      return;
    }

    ref
        .read(profileProvider.notifier)
        .setInvestorProfile(companyName: company, investorKind: kind);
    _goTo(_index + 1);
  }

  void _submitOrgDetails() {
    final address = _address.text.trim();
    final description = _description.text.trim();
    final contact = _contactEmail.text.trim();

    if (address.isEmpty) {
      setState(() => _error = 'Kurumunun adresini gir.');
      return;
    }
    if (description.isEmpty) {
      setState(() => _error = 'Kısa bir açıklama yaz.');
      return;
    }
    if (!_emailPattern.hasMatch(contact)) {
      setState(() => _error = 'Geçerli bir iletişim e-postası gir.');
      return;
    }

    final organization = ref.read(organizationProvider).organization;
    ref.read(organizationProvider.notifier).setIdentity(
      address: address,
      description: description,
      brand: organization?.brand ?? BrandColor.azure,
      sector: organization?.sector,
      email: contact,
    );
    _goTo(_index + 1);
  }

  void _submitOrgLinks() {
    ref.read(organizationProvider.notifier).setLinks(
      website: _website.text.trim(),
      instagram: _instagram.text.trim(),
      linkedin: _linkedin.text.trim(),
      phone: _phone.text.trim(),
    );
    _goTo(_index + 1);
  }

  /// Claims the booth and writes the card. The booth can be lost here — two
  /// companies can be on the same summary screen at once — so the failure is
  /// reported and the user is sent back to pick again.
  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(organizationProvider.notifier).publish();
      if (!mounted) return;
      setState(() => _busy = false);
      context.go('/home');
    } on StandTakenFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.toString();
      });
      // Only a booth clash sends the user back to the plan; every other
      // failure is about the write itself, and the answer is to retry here.
      _goTo(_steps.indexOf(_Step.standPick), clearError: false);
    } on PublishFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kart yayına alınamadı: $error';
      });
    }
  }

  bool _canAdvance(UserProfile profile, OrgState orgState) {
    if (_busy) return false;
    return switch (_step) {
      _Step.identity || _Step.verify => true,
      // Both answers are checked on submit rather than here, so the reason the
      // step will not pass is spelled out instead of shown as a dead button.
      _Step.investorProfile => true,
      _Step.sectors => profile.sectors.isNotEmpty,
      // Both halves of the screen, because either one alone would rank the
      // whole hall on a single signal.
      _Step.investorFocus =>
        profile.stages.isNotEmpty && profile.markets.isNotEmpty,
      _Step.orgDetails || _Step.orgLinks || _Step.ventureDetails => true,
      _Step.standPick => orgState.organization?.standCode != null,
      // Both are chip choices with nothing to type, so the button waits for
      // them rather than complaining afterwards.
      _Step.ventureFocus =>
        orgState.organization?.stageLabel != null &&
            orgState.organization?.sectorLabel != null &&
            orgState.organization?.marketLabel != null,
      _Step.summary => true,
    };
  }

  String _primaryLabel() => switch (_step) {
    _Step.identity => _signInMode ? 'Giriş yap' : 'Hesabımı oluştur',
    _Step.verify => 'Doğrulamayı kontrol et',
    _Step.investorProfile ||
    _Step.investorFocus ||
    _Step.sectors ||
    _Step.orgDetails ||
    _Step.orgLinks ||
    _Step.ventureDetails ||
    _Step.ventureFocus => 'Devam',
    _Step.standPick => 'Standı onayla',
    _Step.summary => _publishesCard ? 'Kartı yayına al' : 'Take Off\'a başla',
  };

  Widget _pageFor(_Step step, UserProfile profile, UserRole role) {
    return switch (step) {
      _Step.identity => _IdentityPage(
        firstName: _firstName,
        lastName: _lastName,
        email: _email,
        password: _password,
        enabled: !_busy,
        corporate: role == UserRole.corporate,
        signInMode: _signInMode,
        onToggleMode: _busy ? null : _toggleMode,
        onSubmit: _signInMode ? _submitSignIn : _submitIdentity,
      ),
      _Step.verify => _VerifyPage(
        email: profile.email,
        busy: _busy,
        notice: _notice,
        onResend: _busy ? null : _resend,
      ),
      _Step.investorProfile => _InvestorProfilePage(
        company: _company,
        selected: _investorKind,
        enabled: !_busy,
        onSelect: (kind) => setState(() {
          _investorKind = kind;
          _error = null;
        }),
      ),
      _Step.investorFocus => _InvestorFocusPage(
        stages: profile.stages,
        markets: profile.markets,
      ),
      _Step.sectors => _SectorsPage(selected: profile.sectors, role: role),
      _Step.orgDetails => OrgDetailsPage(
        address: _address,
        description: _description,
        contactEmail: _contactEmail,
        enabled: !_busy,
      ),
      _Step.orgLinks => OrgLinksPage(
        website: _website,
        instagram: _instagram,
        linkedin: _linkedin,
        phone: _phone,
        enabled: !_busy,
      ),
      _Step.standPick => const StandPickPage(locked: false),
      _Step.ventureDetails => VentureDetailsPage(
        name: _ventureName,
        pitch: _description,
        contactEmail: _contactEmail,
        enabled: !_busy,
      ),
      _Step.ventureFocus => const VentureFocusPage(),
      _Step.summary => role.publishesCard
          ? const OrgSummaryPage()
          : _SummaryPage(profile: profile, role: role),
    };
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    // Watched, not read: picking a booth is what enables the footer button on
    // the stand step, and that only re-evaluates if this build depends on it.
    final orgState = ref.watch(organizationProvider);
    final role = profile.role;

    // Reachable by deep link or hot restart with no role chosen yet.
    if (role == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                0,
              ),
              child: _OnboardingHeader(
                role: role,
                index: _index,
                total: _steps.length,
                onBack: _back,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final step in _steps) _pageFor(step, profile, role),
                ],
              ),
            ),
            Padding(
              // No keyboard inset here on purpose. `resizeToAvoidBottomInset`
              // already shrinks the body by the keyboard's height, and this
              // context sits *above* the Scaffold — so it still reports the
              // full inset. Adding it counted the keyboard twice, which pushed
              // the header off the top and left a keyboard-sized hole under the
              // button.
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                AppSpace.lg,
              ),
              child: _Footer(
                message: _error ?? _hintFor(profile),
                isError: _error != null,
                busy: _busy,
                label: _primaryLabel(),
                icon: _step == _Step.summary
                    ? Icons.rocket_launch_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: _canAdvance(profile, orgState)
                    ? _onPrimaryAction
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hintFor(UserProfile profile) => switch (_step) {
    _Step.identity => _notice != null
        ? _notice!
        : _signInMode
        ? 'Ajandan ve alanların hesabınla birlikte geri gelir.'
        // An exhibitor is publishing, not just registering; promising privacy
        // here and then printing the card on a QR would be a lie. The founder
        // is in the same position.
        : _isCorporate
        ? 'Kurum kartın fuar boyunca herkese açık olacak.'
        : _isEntrepreneur
        ? 'Girişim kartın fuar boyunca herkese açık olacak.'
        : 'Bilgilerin yalnızca senin hesabında tutulur.',
    _Step.ventureDetails => 'Logo ve renk kartının üstünde görünür.',
    _Step.ventureFocus => _focusHint(),
    _Step.investorFocus => _investorFocusHint(profile),
    // The investor publishes no card, so this is the one place their fund's
    // name is collected — and the request is where it becomes visible.
    _Step.investorProfile =>
      'Bu bilgiler yalnızca görüşme talebi gönderdiğin kurumlarla paylaşılır.',
    _Step.orgDetails => 'Logo ve renk stant kutunda da görünür.',
    _Step.orgLinks => 'Hepsini boş bırakıp geçebilirsin.',
    _Step.standPick =>
      ref.read(organizationProvider).organization?.standCode == null
          ? 'Boş bir stant seç'
          : 'Onayladıktan sonra değiştirilemez.',
    _Step.verify => 'Bağlantıya tıkladığında bu ekran kendiliğinden geçer.',
    _Step.sectors => profile.sectors.isEmpty
        ? _isInvestor
              ? 'En az bir yatırım alanı seç'
              : 'En az bir alan seç'
        : '${profile.sectors.length} alan seçildi',
    _Step.summary => '',
  };

  /// Same idea for the investor's screening criteria.
  String _investorFocusHint(UserProfile profile) {
    if (profile.stages.isEmpty) return 'En az bir aşama seç';
    if (profile.markets.isEmpty) return 'En az bir hedef pazar seç';
    return '${profile.stages.length} aşama  ·  '
        '${profile.markets.length} pazar seçildi';
  }

  /// Names whichever of the two chip answers is still missing, so the disabled
  /// button is never a dead end.
  String _focusHint() {
    final organization = ref.read(organizationProvider).organization;
    if (organization?.stageLabel == null) return 'Bir aşama seç';
    if (organization?.sectorLabel == null) return 'Bir alan seç';
    if (organization?.marketLabel == null) return 'Bir hedef pazar seç';
    return organization!.focusLine!;
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.role,
    required this.index,
    required this.total,
    required this.onBack,
  });

  final UserRole role;
  final int index;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GhostIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              tooltip: 'Geri',
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(child: _RoleBadge(role: role)),
            const SizedBox(width: AppSpace.md),
            Text(
              '${(index + 1).toString().padLeft(2, '0')} / '
              '${total.toString().padLeft(2, '0')}',
              style: AppTypography.eyebrow,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        _ProgressTrack(index: index, total: total, accent: role.accent),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GlassSurface(
        radius: AppRadius.pill,
        blur: 14,
        tint: role.accent,
        tintOpacity: 0.14,
        borderColor: role.accent.withValues(alpha: 0.34),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(role.icon, size: 14, color: role.accent),
            const SizedBox(width: 6),
            Text(
              role.label,
              style: AppTypography.bodySmall.copyWith(
                color: AppPalette.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented progress, one segment per step. Segments rather than a continuous
/// bar so the user can see how many steps are left, not just how far along.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.index,
    required this.total,
    required this.accent,
  });

  final int index;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOut,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: i <= index
                    ? accent
                    : Colors.white.withValues(alpha: 0.10),
                boxShadow: i == index
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.enabled,
    required this.corporate,
    required this.signInMode,
    required this.onToggleMode,
    required this.onSubmit,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController password;
  final bool enabled;

  /// An exhibitor has one name, not a first and a last one.
  final bool corporate;

  final bool signInMode;
  final VoidCallback? onToggleMode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return StepPage(
      title: signInMode
          ? 'Tekrar hoş geldin.'
          : corporate
          ? 'Kurumunu kaydet.'
          : 'Seni tanıyalım.',
      subtitle: signInMode
          ? 'Daha önce kaydolduysan e-postan ve şifrenle devam et.'
          : corporate
          ? 'Bu hesap kurumunun bilgilendirme kartını ve standını yönetir.'
          : 'Bu bilgiler profilini oluşturur; ajandan ve kaydettiklerin bu '
                'hesaba bağlanır.',
      children: [
        AutofillGroup(
          child: Column(
            children: [
              // The name is the account's, not the session's, so signing in
              // does not ask for it again — the profile brings it back.
              if (!signInMode) ...[
                Reveal(
                  delay: const Duration(milliseconds: 160),
                  child: corporate
                      ? GlassField(
                          label: 'KURUM ADI',
                          hint: 'Kurumunun tam adı',
                          controller: firstName,
                          enabled: enabled,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [
                            AutofillHints.organizationName,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GlassField(
                                label: 'AD',
                                hint: 'Adın',
                                controller: firstName,
                                enabled: enabled,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [
                                  AutofillHints.givenName,
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: GlassField(
                                label: 'SOYAD',
                                hint: 'Soyadın',
                                controller: lastName,
                                enabled: enabled,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [
                                  AutofillHints.familyName,
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              Reveal(
                delay: const Duration(milliseconds: 220),
                child: GlassField(
                  label: 'E-POSTA',
                  hint: 'ornek@eposta.com',
                  controller: email,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  helper: signInMode
                      ? null
                      : 'Doğrulama bağlantısını buraya göndereceğiz.',
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Reveal(
                delay: const Duration(milliseconds: 280),
                child: GlassField(
                  label: 'ŞİFRE',
                  hint: signInMode ? 'Şifren' : 'En az 6 karakter',
                  controller: password,
                  enabled: enabled,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: [
                    signInMode
                        ? AutofillHints.password
                        : AutofillHints.newPassword,
                  ],
                  onSubmitted: (_) => onSubmit(),
                  helper: signInMode
                      ? null
                      : 'Cihaz değiştirdiğinde hesabına bununla dönersin.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 340),
          child: _ModeSwitch(signInMode: signInMode, onTap: onToggleMode),
        ),
      ],
    );
  }
}

/// The way back and forth between signing up and signing in.
///
/// Kept on the page rather than behind a menu: a returning visitor who cannot
/// find it will create a second account, fail, and be told their address is
/// already taken — the worst possible first thirty seconds.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.signInMode, required this.onTap});

  final bool signInMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Expanded(
          child: Text(
            signInMode ? 'Hesabın yok mu?' : 'Zaten hesabın var mı?',
            style: AppTypography.bodySmall,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: accent,
            textStyle: AppTypography.label,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          ),
          child: Text(signInMode ? 'Kayıt ol' : 'Giriş yap'),
        ),
      ],
    );
  }
}

class _VerifyPage extends StatelessWidget {
  const _VerifyPage({
    required this.email,
    required this.busy,
    required this.notice,
    required this.onResend,
  });

  final String email;
  final bool busy;
  final String? notice;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return StepPage(
      title: 'E-postanı doğrula.',
      subtitle:
          'Adresine bir doğrulama bağlantısı gönderdik. Bağlantıya tıkladıktan '
          'sonra buraya dönmen yeterli.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: GlassSurface(
            padding: const EdgeInsets.all(AppSpace.lg),
            tint: accent,
            tintOpacity: 0.12,
            borderColor: accent.withValues(alpha: 0.30),
            child: Row(
              children: [
                Icon(Icons.mark_email_unread_rounded, size: 22, color: accent),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GÖNDERİLDİ', style: AppTypography.eyebrow),
                      const SizedBox(height: 3),
                      Text(
                        email.isEmpty ? 'E-posta adresin' : email,
                        style: AppTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 220),
          child: GlassSurface(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _VerifyHint(
                  icon: Icons.inbox_rounded,
                  text: 'Gelen kutunu kontrol et; bazen spam klasörüne düşer.',
                ),
                SizedBox(height: AppSpace.md),
                _VerifyHint(
                  icon: Icons.autorenew_rounded,
                  text:
                      'Bu ekran arka planda kendini kontrol eder, '
                      'doğrulanınca otomatik ilerler.',
                ),
              ],
            ),
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            notice!,
            style: AppTypography.bodySmall.copyWith(color: AppPalette.success),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onResend,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Bağlantıyı tekrar gönder'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              textStyle: AppTypography.label,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifyHint extends StatelessWidget {
  const _VerifyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppPalette.textTertiary),
        const SizedBox(width: AppSpace.md),
        Expanded(child: Text(text, style: AppTypography.bodySmall)),
      ],
    );
  }
}

/// The investor's own step: who they invest for, and with what kind of money.
///
/// Deliberately two answers and no more. The portfolio's promise is that a
/// founder can tell in one line whether the request in front of them is worth
/// a slot, and a longer form here would buy nothing for that decision.
class _InvestorProfilePage extends StatelessWidget {
  const _InvestorProfilePage({
    required this.company,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final TextEditingController company;
  final InvestorKind? selected;
  final bool enabled;
  final ValueChanged<InvestorKind> onSelect;

  @override
  Widget build(BuildContext context) {
    return StepPage(
      title: 'Kimin adına yatırım yapıyorsun?',
      subtitle:
          'Görüşme talebi gönderdiğinde kurumlar bu iki bilgiyi görür: hangi '
          'şirket ya da fondan geldiğini ve nasıl bir yatırımcı olduğunu.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: GlassField(
            label: 'ŞİRKET / FON ADI',
            hint: 'Örn. Ada Ventures',
            controller: company,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.organizationName],
            helper: 'Kendi adına yatırım yapıyorsan adını yazabilirsin.',
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 220),
          child: const SectionHeader('YATIRIMCI TİPİ'),
        ),
        const SizedBox(height: AppSpace.md),
        for (var i = 0; i < InvestorKind.values.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.md),
          Reveal(
            delay: Duration(milliseconds: 260 + i * 70),
            child: _KindOption(
              kind: InvestorKind.values[i],
              selected: selected == InvestorKind.values[i],
              onTap: () => onSelect(InvestorKind.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// One investor type as a full-width row rather than a chip: the difference
/// between the two is the explanation under the label, and a chip has no room
/// for it.
class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final InvestorKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return PressableGlass(
      onTap: onTap,
      semanticLabel: '${kind.label}. ${kind.blurb}',
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: selected ? accent : Colors.white,
      tintOpacity: selected ? 0.18 : 0.06,
      borderColor: selected
          ? accent.withValues(alpha: 0.58)
          : AppPalette.stroke,
      glow: selected ? accent : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: accent.withValues(alpha: selected ? 0.22 : 0.10),
              border: Border.all(
                color: accent.withValues(alpha: selected ? 0.46 : 0.22),
              ),
            ),
            child: Icon(kind.icon, size: 19, color: accent),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.label, style: AppTypography.titleSmall),
                const SizedBox(height: 3),
                Text(kind.blurb, style: AppTypography.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? accent : AppPalette.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// What the investor screens on: which levels they write into, and how far the
/// company has to be reaching.
///
/// Multi-select on both, because a fund's mandate is a range rather than a
/// point — "pre-seed and seed, national and regional" is the normal answer, and
/// forcing one choice would make the ranking narrower than the investor is.
class _InvestorFocusPage extends ConsumerWidget {
  const _InvestorFocusPage({required this.stages, required this.markets});

  final Set<String> stages;
  final Set<String> markets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(profileProvider.notifier);

    return StepPage(
      title: 'Neye bakıyorsun?',
      subtitle:
          'Ana sayfan bu iki cevaba göre sıralanır: seçtiğin aşamadaki ve '
          'hedef pazardaki girişimler ile kurumlar en üstte çıkar.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: const SectionHeader('BAKTIĞIM AŞAMALAR'),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (var i = 0; i < Taxonomy.stages.length; i++)
              Reveal(
                delay: Duration(milliseconds: 200 + math.min(i, 8) * 26),
                offsetY: 10,
                child: SelectChip(
                  label: Taxonomy.stages[i],
                  selected: stages.contains(Taxonomy.stages[i]),
                  onTap: () => controller.toggleStage(Taxonomy.stages[i]),
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 260),
          child: const SectionHeader('HEDEF PAZAR'),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Kurum ve girişimler de aynı listeden seçiyor; "ulusal alanda iş '
          'yapmak istiyorum" diyen bir kurum, ulusalı seçen yatırımcının '
          'listesinde öne çıkar.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (var i = 0; i < Taxonomy.markets.length; i++)
              Reveal(
                delay: Duration(milliseconds: 300 + i * 30),
                offsetY: 10,
                child: SelectChip(
                  label: Taxonomy.markets[i],
                  selected: markets.contains(Taxonomy.markets[i]),
                  onTap: () => controller.toggleMarket(Taxonomy.markets[i]),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectorsPage extends ConsumerWidget {
  const _SectorsPage({required this.selected, required this.role});

  final Set<String> selected;

  /// The same list means different things per audience: interests for a
  /// visitor, an investment thesis for an investor. Only the framing changes.
  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(profileProvider.notifier);
    final isInvestor = role == UserRole.investor;

    return StepPage(
      title: isInvestor
          ? 'Hangi alanlara yatırım yapıyorsun?'
          : 'Hangi alanlar ilgini çekiyor?',
      subtitle: isInvestor
          ? 'Program ve görüşme talebi göndereceğin kurumlar bu seçime göre '
                'öne çıkar. Sonradan profilinden değiştirebilirsin.'
          : 'Ana sayfadaki program bu seçime göre sıralanır. Sonradan '
                'profilinden değiştirebilirsin.',
      children: [
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (var i = 0; i < Taxonomy.sectors.length; i++)
              Reveal(
                // Capped so a long list still finishes appearing quickly.
                delay: Duration(milliseconds: 140 + math.min(i, 12) * 32),
                offsetY: 12,
                child: SelectChip(
                  label: Taxonomy.sectors[i],
                  selected: selected.contains(Taxonomy.sectors[i]),
                  onTap: () => controller.toggleSector(Taxonomy.sectors[i]),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({required this.profile, required this.role});

  final UserProfile profile;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return StepPage(
      title: 'Profilin hazır.',
      subtitle:
          'Take Off deneyimini bu profile göre kuruyoruz. Her şeyi sonradan '
          'profilinden değiştirebilirsin.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 180),
          child: _SummaryCard(
            label: 'HESABIM',
            icon: Icons.verified_rounded,
            accent: AppPalette.success,
            values: [profile.fullName],
            caption: profile.email,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Reveal(
          delay: const Duration(milliseconds: 250),
          child: _SummaryCard(
            label: 'ROL',
            icon: role.icon,
            accent: role.accent,
            values: [role.label],
            caption: role.goal,
          ),
        ),
        // The investor's fund sits between the account and the thesis, because
        // that is the order the introduction is read in: who you are, who you
        // invest for, what you invest in.
        if (role == UserRole.investor) ...[
          const SizedBox(height: AppSpace.md),
          Reveal(
            delay: const Duration(milliseconds: 290),
            child: _SummaryCard(
              label: 'YATIRIMCI PROFİLİM',
              icon: profile.investorKind?.icon ?? Icons.trending_up_rounded,
              accent: role.accent,
              values: [profile.companyName],
              caption: profile.investorKind?.blurb,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Reveal(
            delay: const Duration(milliseconds: 300),
            child: _SummaryCard(
              label: 'BAKTIĞIM AŞAMA VE PAZAR',
              icon: Icons.filter_alt_rounded,
              accent: role.accent,
              values: profile.stages.toList(),
              caption: profile.markets.isEmpty
                  ? null
                  : 'Hedef pazar: ${profile.markets.join(', ')}',
            ),
          ),
        ],
        const SizedBox(height: AppSpace.md),
        Reveal(
          delay: const Duration(milliseconds: 320),
          child: _SummaryCard(
            label: role == UserRole.investor ? 'YATIRIM ALANLARIM' : 'ALANLARIM',
            icon: Icons.category_rounded,
            accent: role.accent,
            values: profile.sectors.toList(),
          ),
        ),
        // Last, because it is the only thing on this page the user did not
        // type: everything above is their own answers read back, this is what
        // the answers bought.
        const SizedBox(height: AppSpace.md),
        const Reveal(
          delay: Duration(milliseconds: 380),
          child: MatchPreview(),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.values,
    this.caption,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final List<String> values;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: AppSpace.sm),
              Text(label, style: AppTypography.eyebrow),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            values.join(' · '),
            style: AppTypography.titleSmall.copyWith(height: 1.4),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(caption!, style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.message,
    required this.isError,
    required this.busy,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String message;
  final bool isError;
  final bool busy;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fixed height so the button never shifts as the message changes.
        SizedBox(
          height: 34,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                message,
                key: ValueKey(message),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppTypography.bodySmall.copyWith(
                  color: isError ? AppPalette.danger : AppPalette.textSecondary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        AccentButton(
          label: busy ? 'Bekleniyor…' : label,
          icon: busy ? null : icon,
          onPressed: busy ? null : onPressed,
        ),
      ],
    );
  }
}
