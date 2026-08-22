import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../data/event_repository.dart';
import '../../data/organization_repository.dart';
import '../../domain/event_session.dart';
import '../../domain/meeting.dart';
import '../../domain/organization.dart';
import '../../domain/user_profile.dart';
import '../../domain/user_role.dart';
import '../meetings/meetings_controller.dart';
import '../meetings/new_request_action.dart';
import '../meetings/org_picker_sheet.dart';
import '../organization/organization_controller.dart';
import '../organization/widgets/org_card_sheet.dart';
import '../organization/widgets/org_row.dart';
import '../profile/profile_controller.dart';
import '../scan/scan_screen.dart';
import 'home_providers.dart';
import 'widgets/home_header.dart';
import 'widgets/meeting_card.dart';
import 'widgets/panel_row.dart';
import 'widgets/session_card.dart';

/// The visitor's front page: the published programme, ordered by what they
/// said they care about, with one control per row — add it to my day.
///
/// Everything the agenda tab shows starts as a tap here, so this screen is
/// deliberately the only place sessions can be picked up.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final role = profile.role;
    if (role == null) return const Scaffold(body: SizedBox.shrink());

    final programme = ref.watch(feedProvider);
    final recommended = ref.watch(recommendedSessionsProvider);
    final rest = programme
        .where((session) => !recommended.contains(session))
        .toList(growable: false);
    final loading = ref.watch(eventsStreamProvider).isLoading;

    // Two directions, not one list: a founder answers investors *and* asks
    // companies, and those are different sections with different controls.
    final hosted = ref.watch(openHostedMeetingsProvider);
    final sent = ref.watch(openSentMeetingsProvider);

    final isCorporate = role == UserRole.corporate;
    final publishesCard = role.publishesCard;
    final panels = isCorporate
        ? const <Organization>[]
        : ref.watch(panelOrganizationsProvider);
    final ownOrg = publishesCard
        ? ref.watch(organizationProvider).organization
        : null;
    final hasHours = ownOrg?.availability.isNotEmpty ?? false;
    final ownPanel = ownOrg?.panelLabel == null ? null : ownOrg;

    // Cards this account scanned and kept. A visitor keeps them on the agenda
    // and an investor on their requests tab; the two card-publishing roles have
    // nowhere else to look, so they get them here — a company saving a founder
    // it might want to hire needs the list as much as anyone.
    final favourites = role.publishesCard
        ? ref
              .watch(organizationsProvider)
              .where((org) => profile.likedOrgIds.contains(org.id))
              .toList(growable: false)
        : const <Organization>[];

    // Read once so every card in this build agrees on what "now" means.
    final now = DateTime.now();
    final controller = ref.read(profileProvider.notifier);

    Widget card(EventSession session) => SessionCard(
      session: session,
      now: now,
      matchedSectors: session.sectors
          .where(profile.sectors.contains)
          .toList(growable: false),
      saved: profile.savedEventIds.contains(session.id),
      onToggleSave: () => controller.toggleSavedEvent(session.id),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          // Deep bottom inset: the nav bar floats over the content rather than
          // pushing it up, so the last card needs room to clear it.
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.xxxl * 2,
          ),
          children: [
            Reveal(
              child: HomeHeader(
                role: role,
                onScan: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ScanScreen(),
                    fullscreenDialog: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Reveal(
              delay: const Duration(milliseconds: 90),
              child: Text(
                _greeting(now, profile),
                style: AppTypography.displayMedium,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Reveal(
              delay: const Duration(milliseconds: 160),
              child: Text(
                _subtitle(programme.length, profile.savedEventIds.length),
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpace.xxl),

            // The exhibitor's own talk, so publishing it is visibly confirmed
            // rather than something they have to go and check.
            if (isCorporate && ownPanel != null) ...[
              Reveal(
                delay: const Duration(milliseconds: 180),
                child: const SectionHeader('SAHNE SUNUMUM'),
              ),
              const SizedBox(height: AppSpace.lg),
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: PanelRow(
                  organization: ownPanel,
                  onTap: () => showOrgCardSheet(
                    context,
                    organizationId: ownPanel.id,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
            ],

            // Nothing on either side yet. Each audience is missing something
            // different, and an empty screen would read as a broken one.
            if (hosted.isEmpty && sent.isEmpty && role != UserRole.visitor)
              Reveal(
                delay: const Duration(milliseconds: 220),
                child: _NoMeetings(role: role, hasHours: hasHours),
              ),

            // The founder has no requests tab of their own, so the way into a
            // company's open hours lives on their home screen — above the
            // lists, because it is the thing they came to do.
            if (role == UserRole.entrepreneur) ...[
              if (hosted.isEmpty && sent.isEmpty)
                const SizedBox(height: AppSpace.md),
              Reveal(
                delay: const Duration(milliseconds: 230),
                child: NewRequestAction(
                  onTap: () => showOrgPickerSheet(context),
                  title: 'Görüşme talebi gönder',
                  subtitle:
                      'Saatini açan kurumları listele; günü, saati ve türünü '
                      'gör.',
                ),
              ),
              const SizedBox(height: AppSpace.xl),
            ],

            // Requests addressed to this account come first: somebody is
            // waiting on an answer, which outranks anything else on the page.
            if (hosted.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: SectionHeader(
                  'TOPLANTI TALEPLERİ',
                  trailing: Text(
                    '${hosted.length} talep',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < hosted.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 240 + i * 60),
                    child: MeetingCard(
                      meeting: hosted[i],
                      asHost: true,
                      // Only a request that is still open has anything to
                      // answer; a confirmed one can still be called off.
                      onAccept: hosted[i].status == MeetingStatus.requested
                          ? () => ref
                                .read(meetingsControllerProvider)
                                .respond(hosted[i], MeetingStatus.confirmed)
                          : null,
                      onDecline: () => ref
                          .read(meetingsControllerProvider)
                          .respond(hosted[i], MeetingStatus.declined),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            // Then the ones this account is waiting on.
            if (sent.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 210),
                child: SectionHeader(
                  role.canRequestMeetings ? 'GÖRÜŞMELERİM' : 'TOPLANTILARIM',
                  trailing: Text(
                    '${sent.length} kayıt',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < sent.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 250 + i * 60),
                    child: MeetingCard(meeting: sent[i]),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (favourites.isNotEmpty)
              ..._orgSection(
                context,
                title: 'FAVORİLERİM',
                count: '${favourites.length} kart',
                items: favourites,
                delay: 240,
              ),

            // Stage talks the exhibitors booked themselves. Kept separate from
            // the organiser's programme because that is what they are: a
            // company's own session, not a curated one.
            if (!isCorporate && panels.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 220),
                child: SectionHeader(
                  'SAHNE SUNUMLARI',
                  trailing: Text(
                    '${panels.length} sunum',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < panels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 260 + i * 55),
                    child: PanelRow(
                      organization: panels[i],
                      onTap: () => showOrgCardSheet(
                        context,
                        organizationId: panels[i].id,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (programme.isEmpty)
              Reveal(
                delay: const Duration(milliseconds: 240),
                child: _EmptyProgramme(loading: loading),
              )
            else ...[
              if (recommended.isNotEmpty) ...[
                Reveal(
                  delay: const Duration(milliseconds: 240),
                  child: SectionHeader(
                    'SENİN İÇİN',
                    trailing: Text(
                      '${recommended.length} etkinlik',
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                for (var i = 0; i < recommended.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: Reveal(
                      delay: Duration(milliseconds: 300 + i * 60),
                      child: card(recommended[i]),
                    ),
                  ),
                const SizedBox(height: AppSpace.xl),
              ],

              if (rest.isNotEmpty) ...[
                Reveal(
                  child: SectionHeader(
                    'TÜM PROGRAM',
                    trailing: Text(
                      '${rest.length} etkinlik',
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                for (var i = 0; i < rest.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: Reveal(
                      delay: Duration(milliseconds: 60 + i * 40),
                      child: card(rest[i]),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// A titled list of cards, tapping through to the same sheet a scan opens.
  ///
  /// Returned as loose widgets rather than as one column so the sections stay
  /// part of the page's single scrollable — a nested list here would scroll
  /// inside the feed, which on a phone reads as a bug.
  static List<Widget> _orgSection(
    BuildContext context, {
    required String title,
    required String count,
    required List<Organization> items,
    required int delay,
  }) => [
    Reveal(
      delay: Duration(milliseconds: delay),
      child: SectionHeader(
        title,
        trailing: Text(
          count,
          style: AppTypography.bodySmall.copyWith(fontSize: 12),
        ),
      ),
    ),
    const SizedBox(height: AppSpace.lg),
    for (var i = 0; i < items.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Reveal(
          delay: Duration(milliseconds: delay + 40 + i * 55),
          child: OrgRow(
            organization: items[i],
            caption: _detailOf(items[i]),
            onTap: () =>
                showOrgCardSheet(context, organizationId: items[i].id),
          ),
        ),
      ),
    const SizedBox(height: AppSpace.xl),
  ];

  /// Stage first for a venture, because it is what decides whether the rest is
  /// worth reading; a company has no stage and keeps its sector.
  static String? _detailOf(Organization organization) {
    final parts = [?organization.stageLabel, ?organization.sectorLabel];
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  static String _greeting(DateTime now, UserProfile profile) {
    final name = profile.firstName.trim();
    final salutation = switch (now.hour) {
      < 12 => 'Günaydın',
      < 18 => 'İyi günler',
      _ => 'İyi akşamlar',
    };
    return name.isEmpty ? '$salutation.' : '$salutation, $name.';
  }

  static String _subtitle(int programme, int saved) {
    if (programme == 0) return 'Program yayınlandığında burada görünecek.';
    if (saved == 0) {
      return 'Programda $programme etkinlik var. Beğendiklerini ajandana ekle.';
    }
    return 'Programda $programme etkinlik var, $saved tanesi ajandanda.';
  }
}


/// Shown while the programme collection is empty.
///
/// Distinguishes "still fetching" from "nothing published yet", because the
/// two mean very different things to a visitor standing at the venue.
class _EmptyProgramme extends StatelessWidget {
  const _EmptyProgramme({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else
            const Icon(
              Icons.event_note_outlined,
              size: 22,
              color: AppPalette.textTertiary,
            ),
          const SizedBox(height: AppSpace.md),
          Text(
            loading ? 'Program yükleniyor…' : 'Program henüz yayınlanmadı.',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            loading
                ? 'Etkinlik listesi birazdan burada.'
                : 'Etkinlikler eklendiğinde burada listelenir ve tek dokunuşla '
                      'ajandana alabilirsin.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
/// The home screen before this account has a single meeting on it.
///
/// One widget for three audiences because the shape of the answer is the same —
/// icon, sentence, what to do next — while the substance is not: the exhibitor
/// waits (or has no hours open yet), the investor and the founder act, and the
/// founder acts in two directions at once.
class _NoMeetings extends StatelessWidget {
  const _NoMeetings({required this.role, required this.hasHours});

  final UserRole role;

  /// Only meaningful for the roles that receive requests. No hours open is
  /// something to go and fix; no requests yet is something to wait for.
  final bool hasHours;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    final (icon, title, body) = switch (role) {
      UserRole.corporate => (
        hasHours
            ? Icons.mark_email_unread_outlined
            : Icons.event_busy_rounded,
        hasHours ? 'Henüz talep yok.' : 'Henüz saat açmadın.',
        hasHours
            ? 'Standındaki karekodu okutan ziyaretçiler açtığın saatler için '
                  'talep gönderdiğinde burada görünecek.'
            : 'Profil sekmesinden toplantı saatlerini aç; ziyaretçiler ancak o '
                  'zaman senden randevu isteyebilir.',
      ),
      // The founder keeps no hours, so there is nothing here to go and fix —
      // only the first request to send.
      UserRole.entrepreneur => (
        Icons.handshake_outlined,
        'Henüz görüşme talebin yok.',
        'Yukarıdaki listeden bir kuruma talep gönder; fuar alanında standa '
            'dokunarak ya da standın karekodunu okutarak da ulaşabilirsin. '
            'Kurumun açtığı saatler ve görüşmenin yüz yüze mi online mı '
            'olduğu talep ekranında yazıyor.',
      ),
      _ => (
        Icons.handshake_outlined,
        'Henüz görüşmen yok.',
        'GÖRÜŞMELER sekmesinden bir kuruma talep gönder; fuar alanındaki '
            'standlara dokunarak ya da karekod okutarak da ulaşabilirsin.',
      ),
    };

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: role == UserRole.corporate ? AppPalette.textTertiary : accent,
          ),
          const SizedBox(height: AppSpace.md),
          Text(title, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpace.xs),
          Text(body, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
