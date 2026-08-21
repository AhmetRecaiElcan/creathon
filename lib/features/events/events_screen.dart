import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../data/event_repository.dart';
import '../../data/organization_repository.dart';
import '../../domain/card_match.dart';
import '../../domain/event_session.dart';
import '../../domain/organization.dart';
import '../agenda/agenda_providers.dart';
import '../home/home_providers.dart';
import '../home/widgets/panel_row.dart';
import '../home/widgets/session_card.dart';
import '../organization/widgets/org_card_sheet.dart';
import '../profile/profile_controller.dart';

/// Everything with an hour on it, in one tab: what the companies put on stage,
/// and what the foundation put on the programme.
///
/// Split off the investor's home screen because the two answer different
/// questions — "who should I meet" and "where should I be at two o'clock" — and
/// a single page trying to do both buried the second one under the first.
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final controller = ref.read(profileProvider.notifier);

    final saved = ref.watch(savedSessionsProvider);
    final programme = ref.watch(feedProvider);
    final recommended = ref.watch(recommendedSessionsProvider);
    final rest = programme
        .where((session) => !recommended.contains(session))
        .toList(growable: false);
    final loading = ref.watch(eventsStreamProvider).isLoading;

    // Stage talks, with the ones that fit this account's criteria lifted to the
    // top: the list is a menu to choose from, not a timetable to follow, so
    // relevance outranks the clock here.
    final panels = CardMatcher.rank(
      ref.watch(panelOrganizationsProvider),
      MatchCriteria.of(profile),
    );

    final now = DateTime.now();

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
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.xxxl * 2,
          ),
          children: [
            Reveal(
              child: Text('Etkinlikler', style: AppTypography.displayMedium),
            ),
            const SizedBox(height: AppSpace.sm),
            Reveal(
              delay: const Duration(milliseconds: 80),
              child: Text(
                _subtitle(panels.length, programme.length, saved.length),
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            // What this account already committed to, first — a saved talk is
            // the only thing on this page with a claim on their afternoon.
            if (saved.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: SectionHeader(
                  'AJANDAM',
                  trailing: Text(
                    '${saved.length} etkinlik',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < saved.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 160 + i * 50),
                    child: card(saved[i]),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (panels.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 180),
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
                    delay: Duration(milliseconds: 220 + i * 50),
                    child: _PanelEntry(match: panels[i]),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (programme.isEmpty)
              Reveal(
                delay: const Duration(milliseconds: 240),
                child: _EmptyProgramme(loading: loading, hasPanels: panels.isNotEmpty),
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
                      delay: Duration(milliseconds: 280 + i * 50),
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

  static String _subtitle(int panels, int programme, int saved) {
    if (panels == 0 && programme == 0) {
      return 'Program ve sahne sunumları yayınlandığında burada toplanır.';
    }
    if (saved == 0) {
      return 'Sahnedeki sunumlar ve vakfın programı. Beğendiklerini ajandana '
          'ekle.';
    }
    return '$saved etkinlik ajandanda. Sahne sunumları ve program aşağıda.';
  }
}

/// One stage talk. Carries the same "why this is here" line the investor's home
/// uses, so a talk lifted to the top says what lifted it.
class _PanelEntry extends StatelessWidget {
  const _PanelEntry({required this.match});

  final CardMatch match;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final Organization organization = match.organization;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelRow(
          organization: organization,
          onTap: () =>
              showOrgCardSheet(context, organizationId: organization.id),
        ),
        if (match.matched) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.sm),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 12, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Ölçütlerine uyuyor · ${match.reasons.join(', ')}',
                    style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyProgramme extends StatelessWidget {
  const _EmptyProgramme({required this.loading, required this.hasPanels});

  final bool loading;

  /// When the companies have already put talks up, an empty programme is a gap
  /// in the foundation's own list rather than an empty screen.
  final bool hasPanels;

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
                : hasPanels
                ? 'Vakfın programı eklendiğinde sahne sunumlarının yanında '
                      'burada listelenir.'
                : 'Etkinlikler eklendiğinde burada listelenir ve tek dokunuşla '
                      'ajandana alabilirsin.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
