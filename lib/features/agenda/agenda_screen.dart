import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/agenda_entry.dart';
import '../../data/organization_repository.dart';
import '../home/widgets/meeting_card.dart';
import '../home/widgets/session_card.dart';
import '../organization/widgets/org_card_sheet.dart';
import '../organization/widgets/org_row.dart';
import '../profile/profile_controller.dart';
import 'agenda_providers.dart';

/// The user's own day: only what they chose from the home feed, in the order
/// they will live it.
///
/// Nothing lands here automatically. That is the point of the add control on
/// the feed — the agenda is a promise the visitor made to themselves, not a
/// programme dump.
class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final timeline = ref.watch(agendaTimelineProvider);
    final controller = ref.read(profileProvider.notifier);
    final now = DateTime.now();

    // Kept in the order the exhibitors appear in the collection rather than in
    // the order they were liked; the agenda is a day, and stands have no time.
    final liked = ref
        .watch(organizationsProvider)
        .where((org) => profile.likedOrgIds.contains(org.id))
        .toList(growable: false);

    final sessionCount = timeline.whereType<SessionEntry>().length;
    final meetingCount = timeline.whereType<MeetingEntry>().length;

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
            Reveal(child: Text('Ajanda', style: AppTypography.displayMedium)),
            const SizedBox(height: AppSpace.sm),
            Reveal(
              delay: const Duration(milliseconds: 80),
              child: Text(
                timeline.isEmpty
                    ? 'Ana sayfadan eklediğin etkinlikler burada toplanır.'
                    : 'Ana sayfadan eklediğin program, saat sırasıyla.',
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            if (timeline.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 140),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        value: '$sessionCount',
                        label: 'ETKİNLİK',
                        icon: Icons.event_note_rounded,
                        highlight: true,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _StatTile(
                        value: _durationLabel(timeline),
                        label: 'TOPLAM SÜRE',
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    if (meetingCount > 0) ...[
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: _StatTile(
                          value: '$meetingCount',
                          label: 'TOPLANTI',
                          icon: Icons.handshake_rounded,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: SectionHeader(
                  'GÜNÜM',
                  trailing: Text(
                    '${timeline.length} kayıt',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
            ],

            if (liked.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: SectionHeader(
                  // Not "kurumlar" any more: a scan can keep a venture card
                  // just as easily as a company's.
                  'FAVORİLERİM',
                  trailing: Text(
                    '${liked.length} kart',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < liked.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 160 + i * 55),
                    child: OrgRow(
                      organization: liked[i],
                      // The same sheet the scanner opens, so the two never
                      // drift apart.
                      onTap: () => showOrgCardSheet(
                        context,
                        organizationId: liked[i].id,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (timeline.isEmpty && liked.isEmpty)
              const Reveal(
                delay: Duration(milliseconds: 140),
                child: _EmptyAgenda(),
              )
            else if (timeline.isEmpty)
              const SizedBox.shrink()
            else
              for (var i = 0; i < timeline.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 240 + i * 55),
                    child: switch (timeline[i]) {
                      SessionEntry(:final session) => SessionCard(
                        session: session,
                        now: now,
                        matchedSectors: session.sectors
                            .where(profile.sectors.contains)
                            .toList(growable: false),
                        saved: true,
                        onToggleSave: () =>
                            controller.toggleSavedEvent(session.id),
                      ),
                      MeetingEntry(:final meeting) => MeetingCard(
                        meeting: meeting,
                      ),
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// Total booked time as `4s 30dk`, dropping the part that would read as zero.
  static String _durationLabel(List<AgendaEntry> timeline) {
    var minutes = 0;
    for (final entry in timeline) {
      minutes += entry.end.difference(entry.start).inMinutes;
    }
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}dk';
    if (rest == 0) return '${hours}s';
    return '${hours}s ${rest}dk';
  }
}

/// Compact number-over-label tile. [highlight] marks the figure the user
/// actually influences.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GlassSurface(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.lg,
      ),
      tint: highlight ? accent : Colors.white,
      tintOpacity: highlight ? 0.14 : 0.06,
      borderColor: highlight
          ? accent.withValues(alpha: 0.34)
          : AppPalette.stroke,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlight ? accent : AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              color: highlight ? accent : AppPalette.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(fontSize: 9.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 22,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.md),
          Text('Ajandan boş.', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Ana sayfadaki bir etkinliğin yanındaki + düğmesine bastığında '
            'buraya eklenir.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(Icons.add_rounded, size: 17, color: accent),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  'Aradığın düğme bu.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppPalette.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
