import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/meeting.dart';
import '../home/widgets/meeting_card.dart';
import '../organization/organization_controller.dart';
import '../profile/profile_controller.dart';
import 'meetings_controller.dart';
import 'new_request_action.dart';
import 'org_picker_sheet.dart';

/// Görüşmeler, for the two audiences that publish a card.
///
/// The investor already had a tab of their own ([InvestorMeetingsScreen]); this
/// is the same idea for the company and the founder, and it exists because
/// their meetings had only ever been a section part-way down the home screen.
/// A meeting you have to scroll past cards and favourites to reach is a meeting
/// whose *Görüşmeyi bitir* button nobody finds — which is exactly how it was
/// reported.
///
/// Not merged with the investor's screen: that one is built around a fund with
/// no card, so it counts requests sent and keeps a watchlist of companies not
/// yet asked. This one has two sides — requests to answer and requests sent —
/// and a company cannot send any at all.
class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).role;
    final hosted = ref.watch(openHostedMeetingsProvider);
    final sent = ref.watch(openSentMeetingsProvider);

    // A founder asks companies for time; a company only receives. Reading the
    // capability rather than the role keeps this right if a third card-holding
    // audience is ever added.
    final canAsk = role?.canRequestMeetings ?? false;

    final waiting = hosted
        .where((meeting) => meeting.status == MeetingStatus.requested)
        .length;
    final live = [...hosted, ...sent]
        .where((meeting) => meeting.status == MeetingStatus.confirmed)
        .length;
    final done = [...hosted, ...sent]
        .where((meeting) => meeting.status == MeetingStatus.completed)
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
                _summary(
                  waiting: waiting,
                  live: live,
                  done: done,
                  canAsk: canAsk,
                ),
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            if (hosted.isNotEmpty || sent.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: Row(
                  children: [
                    Expanded(
                      child: _Tile(
                        value: '$waiting',
                        label: 'BEKLEYEN',
                        icon: Icons.schedule_rounded,
                        highlight: waiting > 0,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _Tile(
                        value: '$live',
                        label: 'ONAYLI',
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: _Tile(
                        value: '$done',
                        label: 'BİTEN',
                        icon: Icons.task_alt_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (canAsk) ...[
              Reveal(
                delay: const Duration(milliseconds: 160),
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

            // Requests addressed to this account first: somebody is waiting on
            // an answer, which outranks anything else on the page.
            if (hosted.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: SectionHeader(
                  'GELEN TALEPLER',
                  trailing: Text(
                    '${hosted.length} kayıt',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < hosted.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 240 + i * 55),
                    child: MeetingCard(
                      meeting: hosted[i],
                      asHost: true,
                      // Only an unanswered request has anything to accept; a
                      // confirmed one can still be called off.
                      onAccept: hosted[i].status == MeetingStatus.requested
                          ? () => ref
                                .read(meetingsControllerProvider)
                                .respond(hosted[i], MeetingStatus.confirmed)
                          : null,
                      onDecline: hosted[i].status == MeetingStatus.completed
                          ? null
                          : () => ref
                                .read(meetingsControllerProvider)
                                .respond(hosted[i], MeetingStatus.declined),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (sent.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 210),
                child: SectionHeader(
                  'GÖNDERDİKLERİM',
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
                    delay: Duration(milliseconds: 250 + i * 55),
                    child: MeetingCard(meeting: sent[i]),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
            ],

            if (hosted.isEmpty && sent.isEmpty)
              Reveal(
                delay: const Duration(milliseconds: 220),
                child: _Empty(canAsk: canAsk),
              ),
          ],
        ),
      ),
    );
  }

  /// One line that says what needs doing, not what exists.
  ///
  /// An unanswered request is the only thing on this page with a person waiting
  /// at the other end, so it takes the sentence whenever there is one.
  static String _summary({
    required int waiting,
    required int live,
    required int done,
    required bool canAsk,
  }) {
    if (waiting > 0) {
      return '$waiting talep cevabını bekliyor.';
    }
    if (live > 0) {
      return '$live onaylı görüşmen var. Bittiğinde karttan bitir ve '
          'değerlendir.';
    }
    if (done > 0) {
      return '$done görüşme tamamlandı.';
    }
    return canAsk
        ? 'Henüz görüşme yok. Kurumlara talep gönderebilir, sana gelen '
              'talepleri buradan cevaplayabilirsin.'
        : 'Henüz görüşme yok. Sana gelen talepler burada görünür.';
  }
}

/// This tab before the account has a single meeting on it.
///
/// Moved here from the home screen with the sections it belonged to. It is worth
/// keeping rather than replacing with "no meetings yet" because of one branch:
/// a company with no hours open has something to go and *fix*, and saying so —
/// with where to fix it — is the difference between an empty screen and a broken
/// one.
class _Empty extends ConsumerWidget {
  const _Empty({required this.canAsk});

  /// Whether this audience sends requests as well as receiving them.
  final bool canAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final ownOrg = ref.watch(organizationProvider).organization;

    // Only meaningful for a company: no hours open is something to go and fix,
    // where no requests yet is something to wait for. A founder keeps no hours
    // at all, so their card is open by default and there is nothing to fix.
    final hasHours = ownOrg?.availability.isNotEmpty ?? false;

    final (icon, title, body) = canAsk
        ? (
            Icons.handshake_outlined,
            'Henüz görüşmen yok.',
            'Yukarıdaki listeden bir kuruma talep gönder; fuar alanında standa '
                'dokunarak ya da karekodunu okutarak da ulaşabilirsin. Sana '
                'gelen talepler de burada görünür.',
          )
        : hasHours
        ? (
            Icons.mark_email_unread_outlined,
            'Henüz talep yok.',
            'Açtığın saatler için yatırımcı ve girişimciler talep '
                'gönderdiğinde burada görünecek.',
          )
        : (
            Icons.event_busy_rounded,
            'Henüz saat açmadın.',
            'Profil sekmesinden toplantı saatlerini aç; ancak o zaman senden '
                'randevu istenebilir.',
          );

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: hasHours || canAsk ? accent : AppPalette.textTertiary,
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

class _Tile extends StatelessWidget {
  const _Tile({
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.lg,
      ),
      tint: highlight ? accent : null,
      tintOpacity: highlight ? 0.14 : 0.10,
      borderColor: highlight ? accent.withValues(alpha: 0.36) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlight ? accent : AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(value, style: AppTypography.titleMedium.wght(700)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}
