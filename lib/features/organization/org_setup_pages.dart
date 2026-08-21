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
import '../../data/expo_repository.dart';
import '../../domain/brand_color.dart';
import '../../domain/taxonomy.dart';
import '../expo/expo_scene.dart';
import '../expo/stand_logos.dart';
import 'organization_controller.dart';
import 'widgets/org_card.dart';

/// The exhibitor's own details: where to find them, what they do, and the two
/// things that make the booth theirs — the logo and the colour.
class OrgDetailsPage extends ConsumerWidget {
  const OrgDetailsPage({
    super.key,
    required this.address,
    required this.description,
    required this.contactEmail,
    required this.enabled,
  });

  final TextEditingController address;
  final TextEditingController description;
  final TextEditingController contactEmail;
  final bool enabled;

  /// Ample for a 512px logo at quality 80; anything larger is a bug rather
  /// than a picture worth writing to a Firestore document.
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
        // Nothing to recover: the logo stays as it was and the user can retry.
      }
    }

    return StepPage(
      title: 'Kurumunu tanıt.',
      subtitle:
          'Bu bilgiler bilgilendirme kartına ve stant kutunun üstüne çıkar. '
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
                    if (organization.logoBase64 != null)
                      TextButton(
                        onPressed: enabled ? controller.clearLogo : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.textTertiary,
                          textStyle: AppTypography.bodySmall,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text('Logoyu kaldır'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 220),
          child: GlassField(
            label: 'İLETİŞİM E-POSTASI',
            hint: 'iletisim@kurum.com',
            controller: contactEmail,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            helper: 'Kartta görünen adres. Giriş adresinden farklı olabilir.',
          ),
        ),

        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 260),
          child: GlassField(
            label: 'ADRES',
            hint: 'Mahalle, cadde, ilçe / il',
            controller: address,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
          ),
        ),

        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 300),
          child: GlassField(
            label: 'AÇIKLAMA',
            hint: 'Kurumunuz ne yapıyor?',
            controller: description,
            enabled: enabled,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            helper: 'Ziyaretçi kartı okuduğunda ilk bunu okuyacak.',
          ),
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 340),
          child: const SectionHeader('MARKA RENGİ'),
        ),
        const SizedBox(height: AppSpace.md),
        _BrandPicker(
          selected: organization.brand,
          onSelect: (brand) => controller.setIdentity(
            address: address.text,
            description: description.text,
            brand: brand,
            sector: organization.sector,
            email: contactEmail.text,
          ),
        ),

        const SizedBox(height: AppSpace.xl),
        Reveal(
          delay: const Duration(milliseconds: 380),
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
                selected: organization.sector == sector,
                onTap: () => controller.setIdentity(
                  address: address.text,
                  description: description.text,
                  brand: organization.brand,
                  // Tapping the chosen one clears it: the field is optional and
                  // there is no other way back out of a single-select wrap.
                  sector: organization.sector == sector ? '' : sector,
                  email: contactEmail.text,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Colour swatches. Bigger than a chip, because the choice is about the colour
/// itself rather than about the word next to it.
class _BrandPicker extends StatelessWidget {
  const _BrandPicker({required this.selected, required this.onSelect});

  final BrandColor selected;
  final ValueChanged<BrandColor> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.md,
      children: [
        for (final brand in BrandColor.values)
          Semantics(
            button: true,
            selected: brand == selected,
            label: brand.label,
            child: GestureDetector(
              onTap: () => onSelect(brand),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  color: brand.color,
                  border: Border.all(
                    color: brand == selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.18),
                    width: brand == selected ? 3 : 1,
                  ),
                  boxShadow: brand == selected
                      ? [
                          BoxShadow(
                            color: brand.color.withValues(alpha: 0.55),
                            blurRadius: 18,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: brand == selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Optional outward channels. Everything here is skippable — a company with
/// only an e-mail still gets a usable card.
class OrgLinksPage extends StatelessWidget {
  const OrgLinksPage({
    super.key,
    required this.website,
    required this.instagram,
    required this.linkedin,
    required this.phone,
    required this.enabled,
  });

  final TextEditingController website;
  final TextEditingController instagram;
  final TextEditingController linkedin;
  final TextEditingController phone;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return StepPage(
      title: 'Nerelerden ulaşılsın?',
      subtitle:
          'Kartı beğenen ziyaretçi buradan sana gelir. Hepsi isteğe bağlı, '
          'boş bırakılanlar kartta görünmez.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: GlassField(
            label: 'WEB SİTESİ',
            hint: 'kurum.com',
            controller: website,
            enabled: enabled,
            keyboardType: TextInputType.url,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 200),
          child: GlassField(
            label: 'INSTAGRAM',
            hint: '@kurum',
            controller: instagram,
            enabled: enabled,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 240),
          child: GlassField(
            label: 'LINKEDIN',
            hint: 'kurum  ·  ya da tam bağlantı',
            controller: linkedin,
            enabled: enabled,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 280),
          child: GlassField(
            label: 'TELEFON',
            hint: '+90 5xx xxx xx xx',
            controller: phone,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
          ),
        ),
      ],
    );
  }
}

/// Booth selection on the real floor plan.
///
/// The warning is blunt on purpose: the reservation is a create-only write, so
/// once it lands there is no undo in the app and none in the rules either.
class StandPickPage extends ConsumerWidget {
  const StandPickPage({super.key, required this.locked});

  /// True once the card is live, when the plan becomes read-only.
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationProvider).organization;
    final placements = ref.watch(standPlacementsProvider);
    final free = ref.watch(freeStandCodesProvider);
    final chosen = organization?.standCode;
    final accent = Theme.of(context).colorScheme.primary;

    return StepPage(
      title: locked ? 'Standın belli.' : 'Standını seç.',
      subtitle: locked
          ? 'Stant ataması kalıcıdır, bu yüzden değiştirilemez.'
          : 'Boş bir kutuya dokun. Onayladıktan sonra değiştirilemez.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: GlassSurface(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 320,
              child: ExpoSceneView(
                placements: placements,
                logos: ref.watch(standLogosProvider).value ?? const {},
                selectedCode: chosen,
                onSelect: (code) {
                  if (locked || code == null) return;
                  if (!free.contains(code)) return;
                  ref.read(organizationProvider.notifier).pickStand(code);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 220),
          child: GlassSurface(
            padding: const EdgeInsets.all(AppSpace.lg),
            tint: chosen == null ? Colors.white : accent,
            tintOpacity: chosen == null ? 0.06 : 0.14,
            borderColor: chosen == null
                ? AppPalette.stroke
                : accent.withValues(alpha: 0.34),
            child: Row(
              children: [
                Icon(
                  chosen == null
                      ? Icons.touch_app_outlined
                      : Icons.push_pin_rounded,
                  size: 20,
                  color: chosen == null ? AppPalette.textTertiary : accent,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chosen == null
                            ? 'Stand seçilmedi'
                            : 'Stand $chosen seçildi',
                        style: AppTypography.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locked
                            ? 'Bu stant kurumuna kayıtlı.'
                            : '${free.length} stant boş. Dolu kutular '
                                  'seçilemez.',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Last look before the booth is claimed: the card exactly as a visitor will
/// see it after scanning.
class OrgSummaryPage extends ConsumerWidget {
  const OrgSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationProvider).organization;
    if (organization == null) return const SizedBox.shrink();

    return StepPage(
      title: 'Kartın hazır.',
      subtitle:
          'Ziyaretçi standındaki karekodu okuttuğunda tam olarak bunu '
          'görecek.',
      children: [
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: OrgCard(organization: organization),
        ),
        const SizedBox(height: AppSpace.lg),
        Reveal(
          delay: const Duration(milliseconds: 220),
          child: _PublishWarning(standCode: organization.standCode),
        ),
      ],
    );
  }
}

class _PublishWarning extends StatelessWidget {
  const _PublishWarning({required this.standCode});

  final String? standCode;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: AppPalette.warning,
      tintOpacity: 0.10,
      borderColor: AppPalette.warning.withValues(alpha: 0.30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppPalette.warning,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              'Yayına aldığında ${standCode ?? '—'} standı kurumuna kalıcı '
              'olarak atanır ve değiştirilemez. Diğer bilgileri sonradan '
              'düzenleyebilirsin.',
              style: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
