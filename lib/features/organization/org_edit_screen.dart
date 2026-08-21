import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/select_chip.dart';
import '../../domain/brand_color.dart';
import '../../domain/taxonomy.dart';
import 'organization_controller.dart';
import 'widgets/channel_edit_sheet.dart';
import 'widgets/org_card.dart';

/// Everything on the info card, in one form.
///
/// Reached from the card screen rather than living on the profile: the card is
/// what the exhibitor publishes, so editing it belongs next to the preview of
/// what visitors will see, not filed under account settings.
class OrgEditScreen extends ConsumerStatefulWidget {
  const OrgEditScreen({super.key});

  @override
  ConsumerState<OrgEditScreen> createState() => _OrgEditScreenState();
}

class _OrgEditScreenState extends ConsumerState<OrgEditScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _linkedin = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final organization = ref.read(organizationProvider).organization;
    if (organization == null) return;
    _name.text = organization.name;
    _email.text = organization.email;
    _address.text = organization.address;
    _description.text = organization.description;
    _website.text = organization.website ?? '';
    _instagram.text = organization.instagram ?? '';
    _linkedin.text = organization.linkedin ?? '';
    _phone.text = organization.phone ?? '';
  }

  List<TextEditingController> get _fields => [
    _name,
    _email,
    _address,
    _description,
    _website,
    _instagram,
    _linkedin,
    _phone,
  ];

  @override
  void dispose() {
    for (final controller in _fields) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final controller = ref.read(organizationProvider.notifier);
    final organization = ref.read(organizationProvider).organization;
    if (organization == null) return;

    controller
      ..setIdentity(
        address: _address.text.trim(),
        description: _description.text.trim(),
        brand: organization.brand,
        sector: organization.sector,
        email: _email.text.trim(),
      )
      ..setLinks(
        website: _website.text.trim(),
        instagram: _instagram.text.trim(),
        linkedin: _linkedin.text.trim(),
        phone: _phone.text.trim(),
      )
      ..setName(_name.text.trim())
      ..save();

    Navigator.of(context).maybePop();
    showCardNotice(context, 'Kartın güncellendi.');
  }

  Future<void> _pickLogo() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 600 * 1024) {
        if (mounted) showCardNotice(context, 'Bu logo fazla büyük.');
        return;
      }
      ref.read(organizationProvider.notifier)
        ..setLogo(base64Encode(bytes))
        ..save();
    } catch (_) {
      // The logo stays as it was; the exhibitor can try again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(organizationProvider).organization;
    if (organization == null) return const Scaffold(body: SizedBox.shrink());

    final controller = ref.read(organizationProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                0,
              ),
              child: Row(
                children: [
                  GhostIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Geri',
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      'Kartı düzenle',
                      style: AppTypography.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.lg,
                  AppSpace.xl,
                  AppSpace.xxxl,
                ),
                children: [
                  Reveal(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickLogo,
                          child: OrgLogo(
                            organization: organization,
                            size: 64,
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
                                'Değiştirmek için logoya dokun. Kare bir görsel '
                                'stant kutusunda en iyi görünür.',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader('KURUM BİLGİLERİ'),
                  const SizedBox(height: AppSpace.md),
                  GlassField(label: 'KURUM ADI', controller: _name),
                  const SizedBox(height: AppSpace.lg),
                  GlassField(
                    label: 'İLETİŞİM E-POSTASI',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  GlassField(label: 'ADRES', controller: _address),
                  const SizedBox(height: AppSpace.lg),
                  GlassField(
                    label: 'AÇIKLAMA',
                    controller: _description,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),

                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader('MARKA RENGİ'),
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
                          onTap: () {
                            controller
                              ..setIdentity(
                                address: _address.text.trim(),
                                description: _description.text.trim(),
                                brand: brand,
                                sector: organization.sector,
                                email: _email.text.trim(),
                              )
                              ..save();
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader('ALAN'),
                  const SizedBox(height: AppSpace.md),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final sector in Taxonomy.sectors)
                        SelectChip(
                          label: sector,
                          selected: organization.sectorLabel == sector,
                          onTap: () {
                            controller
                              ..setIdentity(
                                address: _address.text.trim(),
                                description: _description.text.trim(),
                                brand: organization.brand,
                                sector: organization.sectorLabel == sector
                                    ? ''
                                    : sector,
                                email: _email.text.trim(),
                              )
                              ..save();
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader('İLETİŞİM KANALLARI'),
                  const SizedBox(height: AppSpace.md),
                  GlassField(label: 'WEB SİTESİ', controller: _website),
                  const SizedBox(height: AppSpace.lg),
                  GlassField(label: 'INSTAGRAM', controller: _instagram),
                  const SizedBox(height: AppSpace.lg),
                  GlassField(label: 'LINKEDIN', controller: _linkedin),
                  const SizedBox(height: AppSpace.lg),
                  GlassField(
                    label: 'TELEFON',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: AccentButton(
                label: 'Kaydet',
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
