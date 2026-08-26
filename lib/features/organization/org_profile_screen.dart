import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../data/auth_repository.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization.dart';
import '../home/widgets/availability_row.dart';
import '../profile/account_deletion.dart';
import '../profile/profile_controller.dart';
import 'availability_sheet.dart';
import 'organization_controller.dart';
import 'widgets/org_card_sheet.dart';
import 'widgets/org_row.dart';

/// The exhibitor's account settings: the hours they keep, the booth they hold,
/// and the two ways out.
///
/// Everything a visitor can see lives on the card screen instead. What is left
/// here is what only the exhibitor deals with — which is why the booth appears
/// as a statement rather than a field.
class OrgProfileScreen extends ConsumerWidget {
  const OrgProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationProvider).organization;
    if (organization == null) return const Scaffold(body: SizedBox.shrink());

    final controller = ref.read(organizationProvider.notifier);
    final availability = organization.availability;
    final profile = ref.watch(profileProvider);
    final favouriteOrgs = profile.likedOrgIds
        .map((id) => ref.watch(organizationByIdProvider(id)))
        .whereType<Organization>()
        .toList(growable: false);

    Future<void> leave() async {
      await ref.read(authRepositoryProvider).signOut();
      controller.reset();
      ref.read(profileProvider.notifier).reset();
      if (context.mounted) context.go('/');
    }

    final isStartup = organization.kind.isStartup;

    Future<void> remove() async {
      final confirmed = await showDeleteAccountDialog(
        context,
        title: isStartup ? 'Girişimi sil' : 'Kurumu sil',
        message: isStartup
            ? 'Girişim kartın ve gönderdiğin görüşme talepleri silinir, '
                  'hesabın kapatılır. Bu geri alınamaz.'
            : 'Bilgilendirme kartın silinir, '
                  '${organization.standCode ?? '—'} standı boşa çıkar ve '
                  'hesabın kapatılır. Bu geri alınamaz.',
      );
      if (confirmed != true || !context.mounted) return;

      try {
        await ref.read(accountDeletionProvider).deleteCorporate();
        if (context.mounted) context.go('/');
      } on AuthFailure catch (failure) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppPalette.inkOverlay,
              content: Text(
                failure.message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
          );
      }
    }

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
              child: Text(
                organization.kind.label,
                style: AppTypography.displayMedium,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Reveal(
              delay: const Duration(milliseconds: 80),
              child: Text(
                organization.name,
                style: AppTypography.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            // The booth is the one thing on this screen a startup does not
            // have; it gets the stage it is at instead, which is the fact its
            // own account most often needs to correct.
            Reveal(
              delay: const Duration(milliseconds: 140),
              child: isStartup
                  ? _StageState(
                      stage: organization.stageLabel,
                      sector: organization.sectorLabel,
                    )
                  : _StandLock(standCode: organization.standCode),
            ),

            // Hours belong to the side that stands still. A founder walks the
            // hall asking companies for time, so there is nothing to open here
            // — and an empty grid would only invite them to wait for requests
            // that cannot arrive.
            if (!isStartup) ...[
              const SizedBox(height: AppSpace.xl),
              Reveal(
                delay: const Duration(milliseconds: 180),
                child: SectionHeader(
                  'TOPLANTI SAATLERİM',
                  trailing: Text(
                    '${availability.length} saat',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                availability.isEmpty
                    ? 'Saat açmadan ziyaretçiler senden toplantı talep edemez.'
                    : 'Bir saate dokunarak türünü ve açıklamasını '
                          'değiştirebilir ya da kapatabilirsin. Gelen talepler '
                          'ana sayfanda görünür.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpace.md),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  AddAvailabilityButton(
                    onTap: () => showAvailabilitySheet(context),
                  ),
                  for (final slot in availability)
                    AvailabilityChip(
                      slot: slot,
                      onTap: () =>
                          showAvailabilitySheet(context, existing: slot),
                    ),
                ],
              ),
            ],

            const SizedBox(height: AppSpace.xl),
            Reveal(
              delay: const Duration(milliseconds: 200),
              child: SectionHeader(
                'FAVORİLERİM',
                trailing: Text(
                  '${favouriteOrgs.length} kart',
                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (favouriteOrgs.isEmpty)
              Reveal(
                delay: const Duration(milliseconds: 205),
                child: GlassSurface(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                        color: AppPalette.textTertiary,
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          'Henüz favori kartın yok. '
                          'Fuar alanından veya QR okutarak '
                          'beğendiğin kartları buraya ekle.',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (var i = 0; i < favouriteOrgs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Reveal(
                    delay: Duration(milliseconds: 210 + i * 50),
                    child: OrgRow(
                      organization: favouriteOrgs[i],
                      onTap: () => showOrgCardSheet(
                        context,
                        organizationId: favouriteOrgs[i].id,
                      ),
                    ),
                  ),
                ),

            const SizedBox(height: AppSpace.xl),
            Reveal(
              delay: const Duration(milliseconds: 220),
              child: const SectionHeader('HESAP'),
            ),
            const SizedBox(height: AppSpace.md),
            PressableGlass(
              onTap: leave,
              radius: AppRadius.md,
              tintOpacity: 0.06,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              semanticLabel: 'Oturumu kapat',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: AppPalette.textSecondary,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    'Oturumu kapat',
                    style: AppTypography.label.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            DangerAction(
              label: isStartup ? 'Girişimi sil' : 'Kurumu ve standı sil',
              icon: Icons.delete_forever_rounded,
              onTap: remove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the venture stands today, and a nudge to keep it true.
///
/// A startup's stage is the opposite of the exhibitor's booth: it is the field
/// most likely to be *wrong* a month after signup, so it is stated up front
/// with the card editor named as the place to change it.
class _StageState extends StatelessWidget {
  const _StageState({required this.stage, required this.sector});

  final String? stage;
  final String? sector;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: accent,
      tintOpacity: 0.12,
      borderColor: accent.withValues(alpha: 0.30),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, size: 20, color: accent),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [?stage, ?sector].join('  ·  ').isEmpty
                      ? 'Aşama seçilmedi'
                      : [?stage, ?sector].join('  ·  '),
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Aşaman değiştiğinde KARTIM sekmesindeki DÜZENLE ile '
                  'güncelle; kartını okuyan ilk bunu görüyor.',
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

/// States the one thing about this account that cannot be edited, and why.
class _StandLock extends StatelessWidget {
  const _StandLock({required this.standCode});

  final String? standCode;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: accent,
      tintOpacity: 0.12,
      borderColor: accent.withValues(alpha: 0.30),
      child: Row(
        children: [
          Icon(Icons.push_pin_rounded, size: 20, color: accent),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stand ${standCode ?? '—'}',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Stant ataması kalıcıdır; fuar planının güvenilir kalması '
                  'için değiştirilemez.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 17,
            color: AppPalette.textTertiary,
          ),
        ],
      ),
    );
  }
}
