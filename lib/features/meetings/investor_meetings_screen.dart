import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../data/organization_repository.dart';
import '../../domain/meeting.dart';
import '../home/widgets/meeting_card.dart';
import '../organization/widgets/org_card_sheet.dart';
import '../organization/widgets/org_row.dart';
import '../profile/profile_controller.dart';
import 'meetings_controller.dart';
import 'new_request_action.dart';
import 'org_picker_sheet.dart';

/// The investor's third tab, and the one thing it owns: görüşmeler.
///
/// The investor publishes no card, so nothing here is about being found — it is
/// about reaching out. One action creates a request, the list underneath is
/// every request sent and where it stands, and the watchlist is the companies
/// kept from a scan or the floor plan but not yet asked.
class InvestorMeetingsScreen extends ConsumerWidget {
  const InvestorMeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final meetings = ref.watch(openMeetingsProvider);

    // Watched here so the picker and the watchlist have the exhibitor list
    // loaded before they are opened; nothing else on this tab reads it.
    final organizations = ref.watch(organizationsProvider);
    final askedIds = {for (final meeting in meetings) meeting.organizationId};
    final watchlist = organizations
        .where(
          (org) =>
              profile.likedOrgIds.contains(org.id) && !askedIds.contains(org.id),
        )
        .toList(growable: false);

    final confirmed = meetings
        .where((meeting) => meeting.status == MeetingStatus.confirmed)
        .length;
    final pending = meetings
        .where((meeting) => meeting.status == MeetingStatus.requested)
        .length;

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
              child: Text('Görüşmeler', style: AppTypography.displayMedium),
            ),
            const SizedBox(height: AppSpace.sm),
            Reveal(
              delay: const Duration(milliseconds: 80),
              child: Text(
                meetings.isEmpty
                    ? 'Görüşmek istediğin kuruma talep gönder; onaylandığında '
                          'burada ve ana sayfanda görünür.'
                    : '${meetings.length} talep gönderdin, $confirmed tanesi '
                          'onaylandı.',
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            if (meetings.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        value: '${meetings.length}',
                        label: 'TALEP',
                        icon: Icons.send_rounded,
                        highlight: true,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _StatTile(
                        value: '$confirmed',
                        label: 'ONAYLANAN',
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _StatTile(
                        value: '$pending',
                        label: 'BEKLEYEN',
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
            ],

            Reveal(
              delay: const Duration(milliseconds: 160),
              child: NewRequestAction(
                onTap: () => showOrgPickerSheet(context),
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            if (meetings.isEmpty)
              const Reveal(
                delay: Duration(milliseconds: 220),
                child: _NoRequestsYet(),
              )
            else ...[
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: SectionHeader(
                  'TALEPLERİM',
                  trailing: Text(
                    '${meetings.length} kayıt',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < meetings.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 240 + i * 55),
                    child: MeetingCard(meeting: meetings[i]),
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
            ],

            if (watchlist.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 260),
                child: SectionHeader(
                  'TAKİP LİSTEM',
                  trailing: Text(
                    '${watchlist.length} kurum',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < watchlist.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 300 + i * 55),
                    child: OrgRow(
                      organization: watchlist[i],
                      // The card is where the request action lives, so the row
                      // opens exactly what a scan would have opened.
                      onTap: () => showOrgCardSheet(
                        context,
                        organizationId: watchlist[i].id,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state. Names all three ways in, because the investor who has not sent
/// a request yet is usually the one who has not found the way to yet.
class _NoRequestsYet extends StatelessWidget {
  const _NoRequestsYet();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.handshake_outlined,
            size: 22,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.md),
          Text('Henüz talep göndermedin.', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpace.md),
          const _Way(
            icon: Icons.add_circle_outline_rounded,
            text: 'Yukarıdaki karttan kurum listesinden seç.',
          ),
          const SizedBox(height: AppSpace.md),
          const _Way(
            icon: Icons.view_in_ar_outlined,
            text: 'Fuar alanında bir standa dokun.',
          ),
          const SizedBox(height: AppSpace.md),
          const _Way(
            icon: Icons.qr_code_scanner_rounded,
            text: 'Standın karekodunu okut.',
          ),
        ],
      ),
    );
  }
}

class _Way extends StatelessWidget {
  const _Way({required this.icon, required this.text});

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

/// Compact number-over-label tile. [highlight] marks the figure the investor
/// actually moves.
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
