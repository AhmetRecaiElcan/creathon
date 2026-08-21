import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/select_chip.dart';
import '../../data/auth_repository.dart';
import '../../domain/investor_kind.dart';
import '../../domain/profile_wallpaper.dart';
import '../../domain/taxonomy.dart';
import '../../domain/user_profile.dart';
import '../../domain/user_role.dart';
import '../agenda/agenda_providers.dart';
import '../home/home_providers.dart';
import '../meetings/meetings_controller.dart';
import 'account_deletion.dart';
import 'profile_controller.dart';

/// Identity on top, interests underneath.
///
/// The interests are editable here rather than read-only because they are the
/// single input the feed derives from: adding a sector reorders the home
/// programme immediately, which is the clearest way to show the
/// personalisation is real.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Firestore caps a document at 1 MiB and base64 adds a third; a picture
  /// that still exceeds this after downsizing is a bug worth reporting rather
  /// than a write worth attempting.
  static const _maxPhotoBytes = 600 * 1024;

  static void _complain(BuildContext context, String message) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final role = profile.role;
    if (role == null) return const Scaffold(body: SizedBox.shrink());

    final controller = ref.read(profileProvider.notifier);
    final savedCount = ref.watch(savedSessionsProvider).length;
    final recommendedCount = ref.watch(recommendedSessionsProvider).length;

    Future<void> leave() async {
      await ref.read(authRepositoryProvider).signOut();
      controller.reset();
      if (context.mounted) context.go('/');
    }

    Future<void> pick(ImageSource source) async {
      try {
        // The picker resizes and re-encodes natively, so what comes back is
        // already a small JPEG — no image package and no second pass needed.
        final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxPhotoBytes) {
          if (context.mounted) _complain(context, 'Bu fotoğraf fazla büyük.');
          return;
        }
        controller.setPhoto(base64Encode(bytes));
      } catch (error) {
        if (context.mounted) {
          _complain(context, 'Fotoğraf seçilemedi: $error');
        }
      }
    }

    void editPhoto() {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _PhotoSheet(
          canRemove: profile.photoBase64 != null,
          onPick: (source) {
            Navigator.of(sheetContext).pop();
            pick(source);
          },
          onRemove: () {
            Navigator.of(sheetContext).pop();
            controller.clearPhoto();
          },
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxxl * 2),
        children: [
          _ProfileCover(profile: profile, role: role, onEditPhoto: editPhoto),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpace.lg),
                Reveal(
                  delay: const Duration(milliseconds: 140),
                  child: GlassSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg,
                      vertical: AppSpace.lg,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // An investor's first number is the one they moved:
                        // requests sent. A visitor's is the day they built.
                        if (role == UserRole.investor)
                          _Counter(
                            value: ref.watch(meetingsProvider).length,
                            label: 'GÖRÜŞME',
                          )
                        else
                          _Counter(value: savedCount, label: 'AJANDAM'),
                        _Counter(
                          value: profile.sectors.length,
                          label: 'ALANIM',
                        ),
                        _Counter(value: recommendedCount, label: 'ÖNERİ'),
                      ],
                    ),
                  ),
                ),

                // The investor's fund and kind, editable in place. They are on
                // every request this account sends, so they belong with the
                // identity rather than buried under settings.
                if (role == UserRole.investor) ...[
                  const SizedBox(height: AppSpace.xl),
                  Reveal(
                    delay: const Duration(milliseconds: 160),
                    child: const SectionHeader('YATIRIMCI PROFİLİM'),
                  ),
                  const SizedBox(height: AppSpace.md),
                  _InvestorCard(
                    profile: profile,
                    onEditCompany: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _CompanySheet(
                        initial: profile.companyName,
                        onSave: (name) => controller.setInvestorProfile(
                          companyName: name,
                        ),
                      ),
                    ),
                    onSelectKind: (kind) =>
                        controller.setInvestorProfile(investorKind: kind),
                  ),
                ],

                const SizedBox(height: AppSpace.xl),
                Reveal(
                  delay: const Duration(milliseconds: 180),
                  child: const SectionHeader('DUVAR KÂĞIDIM'),
                ),
                const SizedBox(height: AppSpace.md),
                _WallpaperPicker(
                  selected: profile.wallpaper,
                  onSelect: controller.setWallpaper,
                ),

                const SizedBox(height: AppSpace.xl),
                Reveal(
                  delay: const Duration(milliseconds: 220),
                  child: SectionHeader(
                    role == UserRole.investor
                        ? 'YATIRIM ALANLARIM'
                        : 'ALANLARIM',
                    trailing: Text(
                      '${profile.sectors.length} seçili',
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final sector in Taxonomy.sectors)
                      SelectChip(
                        label: sector,
                        selected: profile.sectors.contains(sector),
                        onTap: () => controller.toggleSector(sector),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpace.xl),
                Reveal(
                  delay: const Duration(milliseconds: 260),
                  child: const SectionHeader('HESAP'),
                ),
                const SizedBox(height: AppSpace.md),
                _RoleCard(role: role, onLeave: leave),

                const SizedBox(height: AppSpace.md),
                DangerAction(
                  label: 'Hesabımı sil',
                  icon: Icons.delete_forever_rounded,
                  onTap: () async {
                    final confirmed = await showDeleteAccountDialog(
                      context,
                      title: 'Hesabı sil',
                      message: role == UserRole.investor
                          ? 'Profilin, gönderdiğin görüşme talepleri ve takip '
                                'listen silinir. Bu geri alınamaz.'
                          : 'Profilin, ajandan ve beğendiğin kurumlar silinir. '
                                'Bu geri alınamaz.',
                    );
                    if (confirmed != true || !context.mounted) return;
                    try {
                      await ref.read(accountDeletionProvider).deleteVisitor();
                      if (context.mounted) context.go('/');
                    } on AuthFailure catch (failure) {
                      if (context.mounted) {
                        _complain(context, failure.message);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wallpaper, avatar, name and address in one block.
///
/// The cover bleeds to the top edge behind the status bar on purpose: it is
/// the only place in the app where the user's own choice, rather than the
/// role's accent, decides what a whole region looks like.
class _ProfileCover extends StatelessWidget {
  const _ProfileCover({
    required this.profile,
    required this.role,
    required this.onEditPhoto,
  });

  final UserProfile profile;
  final UserRole role;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      height: 232 + topInset,
      decoration: BoxDecoration(gradient: profile.wallpaper.gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fades the wallpaper into the app's ink so the content below does
          // not start against a hard horizontal edge.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x99000000)],
                stops: [0.45, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.xl,
              topInset + AppSpace.lg,
              AppSpace.xl,
              AppSpace.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('PROFİL', style: AppTypography.eyebrow),
                    const Spacer(),
                    _RolePill(role: role),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Avatar(
                      initials: profile.initials,
                      photoBase64: profile.photoBase64,
                      accent: role.accent,
                      onTap: onEditPhoto,
                    ),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            // Falls back to the audience rather than to
                            // "Ziyaretçi", which would be the wrong word on
                            // three of the four portfolios.
                            profile.fullName.isEmpty
                                ? role.label
                                : profile.fullName,
                            style: AppTypography.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.email,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppPalette.textPrimary.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.emailVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: AppPalette.success,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.photoBase64,
    required this.accent,
    required this.onTap,
  });

  final String initials;
  final String? photoBase64;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = photoBase64;

    return Semantics(
      button: true,
      label: 'Profil fotoğrafını değiştir',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.ink.withValues(alpha: 0.55),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.42),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 26,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: photo == null
                  ? Text(initials, style: AppTypography.titleLarge)
                  : Image.memory(
                      base64Decode(photo),
                      fit: BoxFit.cover,
                      width: 68,
                      height: 68,
                      // A corrupt string must not take the whole screen down
                      // with it; the initials are always a valid fallback.
                      errorBuilder: (_, _, _) =>
                          Text(initials, style: AppTypography.titleLarge),
                    ),
            ),
            // Small badge so the avatar reads as editable rather than as a
            // decoration that happens to be round.
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.ink.withValues(alpha: 0.88),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.40),
                  ),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 12,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choices for the avatar. A sheet rather than an immediate gallery jump, so
/// removing a photo is as reachable as replacing one.
class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({
    required this.canRemove,
    required this.onPick,
    required this.onRemove,
  });

  final bool canRemove;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: GlassSurface(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PhotoOption(
                icon: Icons.photo_library_rounded,
                label: 'Galeriden seç',
                onTap: () => onPick(ImageSource.gallery),
              ),
              _PhotoOption(
                icon: Icons.photo_camera_rounded,
                label: 'Fotoğraf çek',
                onTap: () => onPick(ImageSource.camera),
              ),
              if (canRemove)
                _PhotoOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Fotoğrafı kaldır',
                  color: AppPalette.danger,
                  onTap: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppPalette.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: tint),
            const SizedBox(width: AppSpace.lg),
            Text(label, style: AppTypography.titleSmall.copyWith(color: tint)),
          ],
        ),
      ),
    );
  }
}

/// The investor's fund and kind, both editable where they are read.
///
/// The kind is two taps rather than a hidden form: switching from angel to
/// institutional is a real change of what a founder is being offered, so it
/// should cost one deliberate tap and be visible at a glance the rest of the
/// time.
class _InvestorCard extends StatelessWidget {
  const _InvestorCard({
    required this.profile,
    required this.onEditCompany,
    required this.onSelectKind,
  });

  final UserProfile profile;
  final VoidCallback onEditCompany;
  final ValueChanged<InvestorKind> onSelectKind;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ŞİRKET / FON', style: AppTypography.eyebrow),
                    const SizedBox(height: 3),
                    Text(
                      profile.companyName.isEmpty
                          ? 'Belirtilmedi'
                          : profile.companyName,
                      style: AppTypography.titleMedium,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              GhostIconButton(
                icon: Icons.edit_rounded,
                tooltip: 'Şirket adını düzenle',
                onPressed: onEditCompany,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text('YATIRIMCI TİPİ', style: AppTypography.eyebrow),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final kind in InvestorKind.values)
                SelectChip(
                  label: kind.label,
                  icon: kind.icon,
                  selected: profile.investorKind == kind,
                  onTap: () => onSelectKind(kind),
                ),
            ],
          ),
          if (profile.investorKind != null) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: accent),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Talep gönderdiğin kurumlar bu bilgiyi görür.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One field, one button. A sheet rather than an inline text field so the name
/// is either changed on purpose or left exactly as it was.
class _CompanySheet extends StatefulWidget {
  const _CompanySheet({required this.initial, required this.onSave});

  final String initial;
  final ValueChanged<String> onSave;

  @override
  State<_CompanySheet> createState() => _CompanySheetState();
}

class _CompanySheetState extends State<_CompanySheet> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Bir şirket ya da fon adı gir.');
      return;
    }
    widget.onSave(name);
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
              Text('YATIRIMCI PROFİLİM', style: AppTypography.eyebrow),
              const SizedBox(height: AppSpace.md),
              GlassField(
                label: 'ŞİRKET / FON ADI',
                hint: 'Örn. Ada Ventures',
                controller: _controller,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  _error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppPalette.danger,
                  ),
                ),
              ],
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

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: AppPalette.ink.withValues(alpha: 0.45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 14, color: AppPalette.textPrimary),
          const SizedBox(width: 6),
          Text(
            role.label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: AppPalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WallpaperPicker extends StatelessWidget {
  const _WallpaperPicker({required this.selected, required this.onSelect});

  final ProfileWallpaper selected;
  final ValueChanged<ProfileWallpaper> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: ProfileWallpaper.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
        itemBuilder: (context, index) {
          final wallpaper = ProfileWallpaper.values[index];
          final isSelected = wallpaper == selected;
          return Semantics(
            button: true,
            selected: isSelected,
            label: '${wallpaper.label} duvar kâğıdı',
            child: GestureDetector(
              onTap: () => onSelect(wallpaper),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  gradient: wallpaper.gradient,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppPalette.stroke,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 8),
                child: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onLeave});

  final UserRole role;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: role.accent,
      tintOpacity: 0.12,
      borderColor: role.accent.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ROLÜM', style: AppTypography.eyebrow),
          const SizedBox(height: 3),
          Text(role.label, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpace.sm),
          Text(role.goal, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpace.lg),
          PressableGlass(
            onTap: onLeave,
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
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: AppTypography.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.primary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.eyebrow.copyWith(fontSize: 9.5)),
      ],
    );
  }
}
