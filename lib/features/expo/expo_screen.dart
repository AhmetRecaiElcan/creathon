import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../data/expo_layout.dart';
import '../../data/expo_repository.dart';
import '../../domain/expo_stand.dart';
import '../organization/widgets/org_card_sheet.dart';
import '../scan/scan_screen.dart';
import 'expo_scene.dart';
import 'stand_logos.dart';

/// The fair floor as a 3D model.
///
/// The hall is an L, the booths are extruded boxes on it, and every booth with
/// no company assigned yet stays grey. Those grey boxes are the contract with
/// the corporate portfolio: it writes a name, a colour and a logo against a
/// booth code, and this screen renders it without another change here.
class ExpoScreen extends ConsumerStatefulWidget {
  const ExpoScreen({super.key});

  @override
  ConsumerState<ExpoScreen> createState() => _ExpoScreenState();
}

class _ExpoScreenState extends ConsumerState<ExpoScreen> {
  final _sceneKey = GlobalKey<ExpoSceneViewState>();
  String? _selected;

  /// Tapping a booth selects it, and — when a company stands there — opens its
  /// card straight away.
  ///
  /// The boxes carry logos rather than names, so a tap is how the visitor finds
  /// out who this is; making them tap the booth and then the strip below would
  /// put a second step in front of the only question they asked.
  void _onSelect(List<StandPlacement> placements, String? code) {
    setState(() => _selected = code);
    if (code == null) return;

    final occupant = placements
        .firstWhere((placement) => placement.stand.code == code)
        .occupant;
    if (occupant == null) return;

    showOrgCardSheet(context, organizationId: occupant.organizationId);
  }

  @override
  Widget build(BuildContext context) {
    final placements = ref.watch(standPlacementsProvider);
    final taken = placements.where((p) => !p.isEmpty).length;
    final selected = placements
        .where((p) => p.stand.code == _selected)
        .firstOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xl,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Reveal(
                          child: Text(
                            'Fuar Alanı',
                            style: AppTypography.displayMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Reveal(
                          delay: const Duration(milliseconds: 80),
                          child: Text(
                            '${ExpoLayout.hall.name} · $taken / '
                            '${placements.length} stand dolu.',
                            style: AppTypography.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  // The scanner belongs here as much as on the home screen:
                  // this is the tab a visitor has open while standing in the
                  // hall with a booth's card in front of them.
                  Reveal(
                    delay: const Duration(milliseconds: 60),
                    child: _ScanPill(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ScanScreen(),
                          fullscreenDialog: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                child: Reveal(
                  delay: const Duration(milliseconds: 140),
                  child: GlassSurface(
                    radius: AppRadius.lg,
                    padding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ExpoSceneView(
                            key: _sceneKey,
                            placements: placements,
                            logos: ref.watch(standLogosProvider).value ?? const {},
                            selectedCode: _selected,
                            onSelect: (code) => _onSelect(placements, code),
                          ),
                        ),
                        Positioned(
                          left: AppSpace.md,
                          top: AppSpace.md,
                          child: const _Hint(),
                        ),
                        Positioned(
                          right: AppSpace.md,
                          top: AppSpace.md,
                          child: _SceneButton(
                            icon: Icons.center_focus_strong_rounded,
                            tooltip: 'Görünümü sıfırla',
                            onTap: () {
                              _sceneKey.currentState?.resetCamera();
                              setState(() => _selected = null);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xl,
                AppSpace.xxxl * 1.6,
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: selected == null
                    ? const _Legend()
                    : _StandDetail(placement: selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.pill,
      blur: 12,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.threed_rotation_rounded,
            size: 13,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(width: 6),
          Text('SÜRÜKLE · YAKINLAŞ → LOGOLAR', style: AppTypography.eyebrow),
        ],
      ),
    );
  }
}

class _SceneButton extends StatelessWidget {
  const _SceneButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          radius: AppRadius.pill,
          blur: 12,
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Icon(icon, size: 18, color: AppPalette.textSecondary),
        ),
      ),
    );
  }
}

/// Shown while nothing is selected, so the strip below the model is never an
/// empty gap and the grey boxes get explained before they are tapped.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: const Color(0xFF767C93).withValues(alpha: 0.65),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Boş standlar gri.', style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Her kutu standı alan firmanın rengi. Yakınlaştırdıkça '
                  'logo tabelaları açılır; kart için standa dokun.',
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

class _StandDetail extends StatelessWidget {
  const _StandDetail({required this.placement});

  final StandPlacement placement;

  @override
  Widget build(BuildContext context) {
    final occupant = placement.occupant;
    final color = occupant?.color ?? const Color(0xFF767C93);

    final surface = GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: color,
      tintOpacity: 0.14,
      borderColor: color.withValues(alpha: 0.36),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: color.withValues(alpha: 0.24),
              border: Border.all(color: color.withValues(alpha: 0.48)),
            ),
            child: Text(
              placement.label.substring(0, 1).toUpperCase(),
              style: AppTypography.titleMedium,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'STAND ${placement.stand.code}',
                      style: AppTypography.eyebrow,
                    ),
                    if (placement.isEmpty) ...[
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        '· BOŞ',
                        style: AppTypography.eyebrow.copyWith(
                          color: AppPalette.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  occupant?.company ?? 'Henüz atanmadı',
                  style: AppTypography.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  occupant == null
                      ? 'Bu stand bir kurum kaydolduğunda burada görünecek.'
                      : occupant.sector ?? 'Kartı görmek için dokun.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          if (occupant != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppPalette.textTertiary,
            ),
        ],
      ),
    );

    // An occupied booth is a doorway to the exhibitor's card; an empty one has
    // nothing behind it, so it stays inert rather than offering a dead tap.
    final occupied = occupant;
    if (occupied == null) return surface;

    return GestureDetector(
      onTap: () => showOrgCardSheet(
        context,
        organizationId: occupied.organizationId,
      ),
      child: surface,
    );
  }
}


/// Opens the scanner from the floor plan.
///
/// Labelled rather than a bare icon: it is the one action on this screen that
/// leaves it, and a lone QR glyph among the camera controls would read as
/// another view toggle.
class _ScanPill extends StatelessWidget {
  const _ScanPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Karekod okut',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassSurface(
          radius: AppRadius.pill,
          blur: 14,
          tint: accent,
          tintOpacity: 0.16,
          borderColor: accent.withValues(alpha: 0.38),
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
                color: accent,
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
    );
  }
}
