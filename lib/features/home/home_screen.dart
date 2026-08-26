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
import '../../domain/match_insight.dart';
import '../../domain/organization.dart';
import '../../domain/user_profile.dart';
import '../../domain/user_role.dart';
import '../matching/match_providers.dart';
import '../matching/widgets/match_score_badge.dart';
import '../organization/organization_controller.dart';
import '../organization/widgets/org_card_sheet.dart';
import '../organization/widgets/org_row.dart';
import '../profile/profile_controller.dart';
import '../scan/scan_screen.dart';
import 'home_providers.dart';
import 'widgets/home_header.dart';
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

    final isCorporate = role == UserRole.corporate;
    final publishesCard = role.publishesCard;
    final panels = isCorporate
        ? const <Organization>[]
        : ref.watch(panelOrganizationsProvider);
    final ownOrg = publishesCard
        ? ref.watch(organizationProvider).organization
        : null;
    final ownPanel = ownOrg?.panelLabel == null ? null : ownOrg;

    // Who this account should be talking to. The founder's side of what the
    // investor's home has always been: the exhibitor looking for a pilot and
    // the venture looking for a partner are asking the same question, and until
    // now only one of them had a screen that answered it.
    final matches = publishesCard
        ? ref.watch(strongMatchesProvider)
        : const <MatchInsight>[];

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

            // Meetings are not on this page any more — neither the requests
            // waiting for an answer, nor the ones this account sent, nor the
            // empty state that stood in for them. They all live on the
            // GÖRÜŞMELER tab now.
            //
            // They were here first because the card-publishing roles had no tab
            // of their own, and the section stayed after they got one. Two
            // screens listing the same requests, each with its own accept and
            // decline, meant answering in one place while looking at the other —
            // and it pushed the programme far enough down that the home screen
            // stopped being about the event.

            if (matches.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 210),
                child: SectionHeader(
                  'EŞLEŞMELERİM',
                  trailing: Text(
                    '${matches.length} kart',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Reveal(
                delay: const Duration(milliseconds: 215),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MatchEngineChip(
                    status: ref.watch(matchEngineStatusProvider),
                    model: ref.watch(matchModelProvider),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < matches.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 240 + i * 55),
                    child: OrgRow(
                      organization: matches[i].organization,
                      caption: matches[i].caption,
                      trailing: MatchScoreBadge(insight: matches[i]),
                      onTap: () => showOrgCardSheet(
                        context,
                        organizationId: matches[i].organization.id,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

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
