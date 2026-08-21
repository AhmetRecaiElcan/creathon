import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/accent_button.dart';
import '../../../core/widgets/glass_field.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/organization.dart';
import '../organization_controller.dart';

/// Edits one contact channel, reached from the pencil on that row of the card.
///
/// One field rather than the whole form: the exhibitor tapped a specific line
/// because that line is wrong, and dropping them into a nine-field screen to
/// fix a typo in a handle is a worse answer than the typo.
Future<void> showChannelEditSheet(
  BuildContext context, {
  required OrgChannel channel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ChannelEditSheet(channel: channel),
  );
}

class _ChannelEditSheet extends ConsumerStatefulWidget {
  const _ChannelEditSheet({required this.channel});

  final OrgChannel channel;

  @override
  ConsumerState<_ChannelEditSheet> createState() => _ChannelEditSheetState();
}

class _ChannelEditSheetState extends ConsumerState<_ChannelEditSheet> {
  final _value = TextEditingController();

  @override
  void initState() {
    super.initState();
    final organization = ref.read(organizationProvider).organization;
    _value.text = switch (widget.channel) {
      OrgChannel.website => organization?.website ?? '',
      OrgChannel.email => organization?.email ?? '',
      OrgChannel.instagram => organization?.instagram ?? '',
      OrgChannel.linkedin => organization?.linkedin ?? '',
      OrgChannel.phone => organization?.phone ?? '',
    };
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final controller = ref.read(organizationProvider.notifier);
    final organization = ref.read(organizationProvider).organization;
    final value = _value.text.trim();

    switch (widget.channel) {
      case OrgChannel.website:
        controller.setLinks(website: value);
      case OrgChannel.instagram:
        controller.setLinks(instagram: value);
      case OrgChannel.linkedin:
        controller.setLinks(linkedin: value);
      case OrgChannel.phone:
        controller.setLinks(phone: value);
      case OrgChannel.email:
        // The public address is part of the identity block, not the links, so
        // it goes back through the same setter that owns those fields.
        if (organization == null) break;
        controller.setIdentity(
          address: organization.address,
          description: organization.description,
          brand: organization.brand,
          sector: organization.sector,
          email: value,
        );
    }
    controller.save();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          top: AppSpace.lg,
          bottom: AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: GlassSurface(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KANALI DÜZENLE', style: AppTypography.eyebrow),
              const SizedBox(height: AppSpace.lg),
              GlassField(
                label: widget.channel.label.toUpperCase(),
                hint: widget.channel.hint,
                controller: _value,
                keyboardType: switch (widget.channel) {
                  OrgChannel.email => TextInputType.emailAddress,
                  OrgChannel.phone => TextInputType.phone,
                  OrgChannel.website => TextInputType.url,
                  _ => TextInputType.text,
                },
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                helper: 'Boş bırakırsan bu satır karttan kalkar.',
              ),
              const SizedBox(height: AppSpace.lg),
              AccentButton(
                label: 'Kaydet',
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared complaint used by the card screens.
void showCardNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.inkOverlay,
        content: Text(
          message,
          style: AppTypography.bodySmall.copyWith(
            color: AppPalette.textPrimary,
          ),
        ),
      ),
    );
}
