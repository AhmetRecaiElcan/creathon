import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../data/auth_repository.dart';
import '../home/widgets/availability_row.dart';
import '../profile/account_deletion.dart';
import '../profile/profile_controller.dart';
import 'availability_sheet.dart';
import 'organization_controller.dart';

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

    Future<void> leave() async {
      await ref.read(authRepositoryProvider).signOut();
      controller.reset();
      ref.read(profileProvider.notifier).reset();
      if (context.mounted) context.go('/');
    }

    Future<void> remove() async {
      final confirmed = await showDeleteAccountDialog(
        context,
        title: 'Kurumu sil',
        message:
            'Bilgilendirme kartın silinir, ${organization.standCode ?? '—'} '
            'standı boşa çıkar ve hesabın kapatılır. Bu geri alınamaz.',
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
            Reveal(child: Text('Kurum', style: AppTypography.displayMedium)),
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

            Reveal(
              delay: const Duration(milliseconds: 140),
              child: _StandLock(standCode: organization.standCode),
            ),

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
              label: 'Kurumu ve standı sil',
              icon: Icons.delete_forever_rounded,
              onTap: remove,
            ),
          ],
        ),
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
