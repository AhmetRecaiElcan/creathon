import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/organization.dart';
import '../../domain/qr_payload.dart';
import 'org_edit_screen.dart';
import 'organization_controller.dart';
import 'widgets/org_card.dart';

/// The exhibitor's own tab: the code visitors scan, and the card they get.
///
/// The QR is shown large and on a light plate because it has to be readable
/// from a phone held at arm's length over a stand counter, sometimes off a
/// screen with the brightness turned down — the app's dark glass is the wrong
/// surface for that one element.
class OrgCardScreen extends ConsumerWidget {
  const OrgCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationProvider).organization;
    if (organization == null) return const Scaffold(body: SizedBox.shrink());

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
              child: Text('Kartım', style: AppTypography.displayMedium),
            ),
            const SizedBox(height: AppSpace.sm),
            Reveal(
              delay: const Duration(milliseconds: 80),
              child: Text(
                // An exhibitor's code is printed and left standing on a
                // counter; a founder's is held up on a phone, in front of one
                // person at a time. Same code, two different instructions.
                organization.kind.isStartup
                    ? 'Bu karekodu göster. Okutan yatırımcı ve kurumlar '
                          'aşağıdaki kartı görür ve senden görüşme talep '
                          'edebilir.'
                    : 'Bu karekodu standına koy. Okutan herkes aşağıdaki kartı '
                          'görür ve ajandasına ekleyebilir.',
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            Reveal(
              delay: const Duration(milliseconds: 140),
              child: _QrPlate(organization: organization),
            ),

            const SizedBox(height: AppSpace.xl),
            Reveal(
              delay: const Duration(milliseconds: 200),
              child: SectionHeader(
                'KART ÖNİZLEME',
                trailing: _EditCardButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OrgEditScreen(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Reveal(
              delay: const Duration(milliseconds: 240),
              child: OrgCard(organization: organization),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPlate extends StatelessWidget {
  const _QrPlate({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final payload = QrPayload.forOrganization(organization.id);

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: organization.color,
      tintOpacity: 0.12,
      borderColor: organization.color.withValues(alpha: 0.32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: Colors.white,
            ),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 208,
              backgroundColor: Colors.white,
              // Black on white, not the brand colour: contrast is what a
              // scanner needs, and a mid-tone brand colour on white is the
              // most common reason a printed code fails to read.
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.cardEyebrow ?? organization.badgeLabel,
                      style: AppTypography.eyebrow.copyWith(
                        color: organization.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      organization.name,
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: payload));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppPalette.inkOverlay,
                        content: Text(
                          'Kart bağlantısı kopyalandı.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppPalette.textPrimary,
                          ),
                        ),
                      ),
                    );
                },
                tooltip: 'Bağlantıyı kopyala',
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppPalette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the full card form. Sits on the preview's header because that is
/// where the exhibitor is looking when they notice something is wrong.
class _EditCardButton extends StatelessWidget {
  const _EditCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Kartı düzenle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 15, color: accent),
            const SizedBox(width: 5),
            Text(
              'DÜZENLE',
              style: AppTypography.eyebrow.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
