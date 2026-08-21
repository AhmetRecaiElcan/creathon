import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../data/event_repository.dart';
import '../../domain/event_session.dart';
import '../../domain/meeting.dart';
import '../../domain/user_profile.dart';
import '../../domain/user_role.dart';
import '../meetings/meetings_controller.dart';
import '../organization/organization_controller.dart';
import '../profile/profile_controller.dart';
import '../scan/scan_screen.dart';
import 'home_providers.dart';
import 'widgets/meeting_card.dart';
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

    final meetings = ref.watch(meetingsProvider);
    final isCorporate = role == UserRole.corporate;
    final hasHours = isCorporate
        ? (ref.watch(organizationProvider).organization?.availability.isNotEmpty ??
              false)
        : false;

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
              child: _HomeHeader(
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

            // An exhibitor with no requests yet needs to know why, and where
            // to go about it — an empty screen would read as a broken one.
            if (isCorporate && meetings.isEmpty)
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: _NoRequests(hasHours: hasHours),
              ),

            // Meetings come first: a time someone is expecting you outranks a
            // programme you are still browsing.
            if (meetings.isNotEmpty) ...[
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: SectionHeader(
                  isCorporate ? 'TOPLANTI TALEPLERİ' : 'TOPLANTILARIM',
                  trailing: Text(
                    '${meetings.length} toplantı',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (var i = 0; i < meetings.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 240 + i * 60),
                    child: MeetingCard(
                      meeting: meetings[i],
                      asHost: isCorporate,
                      // Only the exhibitor answers, and only a request that is
                      // still open has anything to answer.
                      onAccept:
                          isCorporate &&
                              meetings[i].status == MeetingStatus.requested
                          ? () => ref
                                .read(meetingsControllerProvider)
                                .respond(meetings[i], MeetingStatus.confirmed)
                          : null,
                      onDecline: isCorporate
                          ? () => ref
                                .read(meetingsControllerProvider)
                                .respond(meetings[i], MeetingStatus.declined)
                          : null,
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.role, required this.onScan});

  final UserRole role;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassSurface(
          radius: AppRadius.pill,
          blur: 14,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(role.icon, size: 14, color: role.accent),
              const SizedBox(width: 6),
              Text(
                role.label.toUpperCase(),
                style: AppTypography.eyebrow.copyWith(color: role.accent),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Scanning is the one thing a visitor does while standing in front of
        // something, so it lives on the first screen rather than behind a tab.
        Semantics(
          button: true,
          label: 'Karekod okut',
          child: GestureDetector(
            onTap: onScan,
            child: GlassSurface(
              radius: AppRadius.pill,
              blur: 14,
              tint: role.accent,
              tintOpacity: 0.16,
              borderColor: role.accent.withValues(alpha: 0.38),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 15,
                    color: role.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'QR OKUT',
                    style: AppTypography.eyebrow.copyWith(
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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

/// The exhibitor's home before anyone has asked for a meeting.
///
/// Splits the two reasons it can be empty, because they need opposite
/// responses: no hours open is something to go and fix, no requests yet is
/// something to wait for.
class _NoRequests extends StatelessWidget {
  const _NoRequests({required this.hasHours});

  final bool hasHours;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasHours
                ? Icons.mark_email_unread_outlined
                : Icons.event_busy_rounded,
            size: 22,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            hasHours ? 'Henüz talep yok.' : 'Henüz saat açmadın.',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            hasHours
                ? 'Standındaki karekodu okutan ziyaretçiler açtığın saatler '
                      'için talep gönderdiğinde burada görünecek.'
                : 'Profil sekmesinden toplantı saatlerini aç; ziyaretçiler '
                      'ancak o zaman senden randevu isteyebilir.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
