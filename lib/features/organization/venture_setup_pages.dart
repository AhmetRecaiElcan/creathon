import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/select_chip.dart';
import '../../core/widgets/step_page.dart';
import '../../domain/brand_color.dart';
import '../../domain/taxonomy.dart';
import 'organization_controller.dart';
import 'widgets/org_card.dart';

/// The founder's venture: what it is called, what it does, where to reach it.
///
/// Deliberately shorter than the exhibitor's equivalent. A startup at a fair
/// has no address worth printing and nothing to be found *at* — the card's job
/// is to make someone want the meeting, and everything that does not serve that
/// is a field the founder fills in standing up, on a phone, in a crowd.
class VentureDetailsPage extends ConsumerWidget {
  const VentureDetailsPage({
    super.key,
    required this.name,
    required this.pitch,
    required this.contactEmail,
    required this.enabled,
  });

  final TextEditingController name;
  final TextEditingController pitch;
  final TextEditingController contactEmail;
  final bool enabled;

  /// Ample for a 512px logo at quality 80, same bound as the exhibitor's.
  static const _maxLogoBytes = 600 * 1024;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationProvider).organization;
    final controller = ref.read(organizationProvider.notifier);
    if (organization == null) return const SizedBox.shrink();

    Future<void> pickLogo() async {
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxLogoBytes) return;
        controller.setLogo(base64Encode(bytes));
      } catch (_) {
        // The logo stays as it was and the founder can retry.
      }
    }

    return StepPage(
      title: 'Girişimini tanıt.',
      subtitle:
          'Bu kart, karekodunu okutan yatırımcı ve kurumların gördüğü tek şey. '
          'Sonradan düzenleyebilirsin.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: Row(
            children: [
              GestureDetector(
                onTap: enabled ? pickLogo : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OrgLogo(organization: organization, size: 72),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.ink.withValues(alpha: 0.9),
                          border: Border.all(color: AppPalette.strokeStrong),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 14,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LOGO', style: AppTypography.eyebrow),
                    const SizedBox(height: 4),
                    Text(
                      organization.logoBase64 == null
                          ? 'Kare bir logo yükle; yoksa baş harfler kullanılır.'
                          : 'Logon yüklendi. Değiştirmek için dokun.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 200),
          child: GlassField(
            label: 'GİRİŞİM ADI',
            hint: 'Girişiminin adı',
            controller: name,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.organizationName],
          ),
        ),

        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 240),
          child: GlassField(
            label: 'NE YAPIYORSUNUZ?',
            hint: 'Bir iki cümleyle anlat',
            controller: pitch,
            enabled: enabled,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            helper: 'Kartı açan ilk bunu okuyacak; kısa ve net tut.',
          ),
        ),

        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 280),
          child: GlassField(
            label: 'İLETİŞİM E-POSTASI',
            hint: 'iletisim@girisim.com',
            controller: contactEmail,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            helper: 'Kartta görünen adres. Giriş adresinden farklı olabilir.',
          ),
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 320),
          child: const SectionHeader('MARKA RENGİ'),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final brand in BrandColor.values)
              SelectChip(
                label: brand.label,
                accent: brand.color,
                selected: organization.brand == brand,
                onTap: () => controller.setVenture(
                  name: name.text,
                  description: pitch.text,
                  email: contactEmail.text,
                  brand: brand,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Stage and field — the two words that decide whether a meeting can happen.
///
/// Split off from the details page because it is a different kind of question:
/// the rest of the card is what the founder wants to say, this is what the
/// person reading it needs to know before they read anything else.
class VentureFocusPage extends ConsumerWidget {
  const VentureFocusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationProvider).organization;
    final controller = ref.read(organizationProvider.notifier);
    if (organization == null) return const SizedBox.shrink();

    return StepPage(
      title: 'Girişimin hangi durumda?',
      subtitle:
          'Aşama ve alan kartındaki ilk satır; hedef pazar da yatırımcının '
          'listesinde seni öne çıkaran üçüncü cevap.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: const SectionHeader('AŞAMA'),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final stage in Taxonomy.stages)
              SelectChip(
                label: stage,
                selected: organization.stageLabel == stage,
                // Tapping the chosen one clears it — a single-select wrap has
                // no other way back out.
                onTap: () => controller.setStage(
                  organization.stageLabel == stage ? '' : stage,
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 220),
          child: const SectionHeader('ALAN'),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final sector in Taxonomy.sectors)
              SelectChip(
                label: sector,
                selected: organization.sectorLabel == sector,
                onTap: () => controller.setSector(
                  organization.sectorLabel == sector ? '' : sector,
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 260),
          child: const SectionHeader('HEDEF PAZAR'),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Nerede iş yapmak istiyorsun? Yatırımcılar bu cevaba göre de '
          'filtreliyor.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final market in Taxonomy.markets)
              SelectChip(
                label: market,
                selected: organization.marketLabel == market,
                onTap: () => controller.setMarket(
                  organization.marketLabel == market ? '' : market,
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 300),
          child: const _FocusNote(),
        ),
      ],
    );
  }
}

/// Says what the two answers above are actually used for, so they do not read
/// as a form for its own sake.
class _FocusNote extends StatelessWidget {
  const _FocusNote();

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
          Icon(Icons.insights_rounded, size: 18, color: accent),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              'Aşama ve alan kartının ilk satırında görünür; seçtiğin alan '
              'aynı zamanda ana sayfandaki programı sana göre sıralar.',
              style: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
