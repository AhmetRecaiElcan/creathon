import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/card_match.dart';
import '../../domain/match_insight.dart';
import '../../domain/org_kind.dart';
import '../../domain/user_role.dart';
import '../matching/match_providers.dart';
import '../matching/widgets/match_score_badge.dart';
import '../organization/widgets/org_card_sheet.dart';
import '../organization/widgets/org_row.dart';
import '../profile/profile_controller.dart';
import '../scan/scan_screen.dart';
import 'widgets/home_header.dart';

/// The investor's front page: who is on the floor, ranked against what they
/// said they were looking for.
///
/// A screen of its own rather than another section on the shared home, because
/// the investor's first question is not "what is happening" but "who should I
/// be talking to". The programme and the stage talks moved to their own tab for
/// the same reason: two jobs on one page made both of them harder to do.
class InvestorHomeScreen extends ConsumerWidget {
  const InvestorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final criteria = MatchCriteria.of(profile);

    final ranked = ref.watch(matchInsightsProvider);
    final matched = ref.watch(strongMatchesProvider);
    final others = ref.watch(otherMatchesProvider);
    final engine = ref.watch(matchEngineStatusProvider);

    // Cards this account kept from a scan or from the floor plan.
    //
    // Here rather than only on the meetings tab: keeping a card is the one
    // thing an investor does with their thumb all day, and the watchlist over
    // there empties itself the moment a request goes out — which made "where
    // did the company I saved go" a fair question with no good answer. The
    // ranked list below still contains them; a favourite is a shortcut to a
    // card, not a category of company.
    final favourites = ranked
        .where((insight) => profile.likedOrgIds.contains(insight.organization.id))
        .toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.xxxl * 2,
          ),
          children: [
            Reveal(
              child: HomeHeader(
                role: UserRole.investor,
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
                profile.firstName.isEmpty
                    ? 'Fırsatlar.'
                    : '${profile.firstName}, fırsatlar.',
                style: AppTypography.displayMedium,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Reveal(
              delay: const Duration(milliseconds: 160),
              child: Text(
                ranked.isEmpty
                    ? 'Kurumlar ve girişimler kartlarını yayına aldığında '
                          'burada listelenir.'
                    : matched.isEmpty
                    ? '${ranked.length} kart yayında. Tezine uyan çıktığında '
                          'en üste taşınır.'
                    : 'Tezine uyan ${matched.length} kart en üstte; '
                          'toplam ${ranked.length} kart yayında.',
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            if (ranked.isNotEmpty)
              Reveal(
                delay: const Duration(milliseconds: 180),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MatchEngineChip(
                    status: engine,
                    model: ref.watch(matchModelProvider),
                  ),
                ),
              ),
            SizedBox(height: ranked.isEmpty ? AppSpace.lg : AppSpace.xl),

            if (!criteria.isEmpty)
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: _CriteriaCard(criteria: criteria),
              ),
            if (!criteria.isEmpty) const SizedBox(height: AppSpace.xl),

            if (ranked.isEmpty)
              const Reveal(
                delay: Duration(milliseconds: 240),
                child: _NoCards(),
              ),

            if (favourites.isNotEmpty)
              ..._section(
                context,
                title: 'FAVORİLERİM',
                count: '${favourites.length} kart',
                matches: favourites,
                delay: 220,
              ),

            if (matched.isNotEmpty)
              ..._section(
                context,
                title: 'SENİN İÇİN',
                count: '${matched.length} kart',
                matches: matched,
                delay: 240,
              ),

            if (others.isNotEmpty)
              ..._section(
                context,
                title: matched.isEmpty ? 'FUARDAKİLER' : 'DİĞERLERİ',
                count: '${others.length} kart',
                matches: others,
                delay: 300,
              ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _section(
    BuildContext context, {
    required String title,
    required String count,
    required List<MatchInsight> matches,
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
    for (var i = 0; i < matches.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Reveal(
          delay: Duration(milliseconds: delay + 40 + i * 50),
          child: OrgRow(
            organization: matches[i].organization,
            // The caption is the ranking's own explanation: the model's
            // sentence when it scored this card, and the labels that actually
            // earned points when it did not. Never a restatement of the card.
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
  ];
}

/// The investor's own filters, restated where the ranking they produce is read.
///
/// Without it a reordered list is magic; with it the list has a stated reason,
/// and the profile tab is one tap away when the reason is wrong.
class _CriteriaCard extends StatelessWidget {
  const _CriteriaCard({required this.criteria});

  final MatchCriteria criteria;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: accent,
      tintOpacity: 0.10,
      borderColor: accent.withValues(alpha: 0.26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.filter_alt_rounded, size: 18, color: accent),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIRALAMA ÖLÇÜTÜM', style: AppTypography.eyebrow),
                const SizedBox(height: 4),
                Text(
                  [
                    if (criteria.sectors.isNotEmpty)
                      criteria.sectors.join(', '),
                    if (criteria.stages.isNotEmpty) criteria.stages.join(', '),
                    if (criteria.markets.isNotEmpty)
                      criteria.markets.join(', '),
                  ].join('  ·  '),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppPalette.textPrimary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Profilinden değiştirebilirsin.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCards extends StatelessWidget {
  const _NoCards();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            OrgKind.startup.icon,
            size: 22,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.md),
          Text('Henüz yayında kart yok.', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Kurumlar ve girişimler kartlarını yayına aldığında, seçtiğin '
            'alan, aşama ve hedef pazara göre sıralanmış olarak burada '
            'görünecek. Fuar alanından ve karekod okutarak da ulaşabilirsin.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
