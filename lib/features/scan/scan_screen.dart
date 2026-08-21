import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/glass_surface.dart';
import '../../domain/qr_payload.dart';
import '../organization/widgets/org_card_sheet.dart';

/// The camera, pointed at a Take Off code.
///
/// Two kinds of code matter on the ground: the info card standing on an
/// exhibitor's booth, and the gate code at the entrance. Both are handled here
/// so a visitor has one place to point the phone rather than having to know in
/// advance what they are about to scan.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Set while a result is on screen. The scanner keeps running underneath, so
  /// without this a code still in frame would re-fire the moment the sheet is
  /// dismissed.
  bool _handling = false;

  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;

    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere((value) => value != null, orElse: () => null);
    final scan = QrPayload.parse(raw);

    if (scan == null) {
      setState(() => _message = 'Bu bir Take Off karekodu değil.');
      return;
    }

    setState(() {
      _handling = true;
      _message = null;
    });
    HapticFeedback.mediumImpact();

    switch (scan) {
      case OrganizationScan(:final organizationId):
        await showOrgCardSheet(context, organizationId: organizationId);
      case EntryScan(:final gate):
        await _showEntry(gate);
    }

    if (!mounted) return;
    setState(() => _handling = false);
  }

  Future<void> _showEntry(String gate) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: GlassSurface(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.how_to_reg_rounded,
                  size: 26,
                  color: AppPalette.success,
                ),
                const SizedBox(height: AppSpace.md),
                Text('Girişin okundu.', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '$gate kapısından giriş yaptın. İyi bir Take Off geçir.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                AccentButton(
                  label: 'Tamam',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AppPalette.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // The plugin's own error screen is an English stack of jargon;
            // this keeps a denied permission explainable.
            errorBuilder: (context, error) => _CameraProblem(error: error),
          ),
          // Dim everything but the target window, so the user knows where to
          // put the code without a tutorial.
          const _ScanMask(),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _Reticle(accent: accent),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      GhostIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Kapat',
                      ),
                      const Spacer(),
                      _TorchButton(controller: _controller),
                    ],
                  ),
                  const Spacer(),
                  GlassSurface(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KAREKOD OKUT', style: AppTypography.eyebrow),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          _message ??
                              'Stand bilgilendirme kartını ya da giriş '
                                  'karekodunu çerçeveye al.',
                          style: AppTypography.bodySmall.copyWith(
                            color: _message == null
                                ? AppPalette.textSecondary
                                : AppPalette.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darkens the frame except for the square in the middle.
class _ScanMask extends StatelessWidget {
  const _ScanMask();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.62,
            colors: [
              Colors.transparent,
              AppPalette.ink.withValues(alpha: 0.86),
            ],
            stops: const [0.55, 1],
          ),
        ),
      ),
    );
  }
}

/// Four corner brackets. Deliberately not a full square: brackets read as
/// "aim here" while a closed box reads as a frame that has to be filled.
class _Reticle extends StatelessWidget {
  const _Reticle({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    const side = 232.0;
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        children: [
          for (final alignment in [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: alignment,
              child: _Corner(alignment: alignment, accent: accent),
            ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment, required this.accent});

  final Alignment alignment;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final top = alignment.y < 0;
    final left = alignment.x < 0;
    final side = BorderSide(color: accent, width: 3);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: top ? BorderSide.none : side,
          left: left ? side : BorderSide.none,
          right: left ? BorderSide.none : side,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(10) : Radius.zero,
          topRight: top && !left ? const Radius.circular(10) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(10) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(10) : Radius.zero,
        ),
      ),
    );
  }
}

class _TorchButton extends StatefulWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  State<_TorchButton> createState() => _TorchButtonState();
}

class _TorchButtonState extends State<_TorchButton> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return GhostIconButton(
      icon: _on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
      tooltip: 'Işık',
      onPressed: () async {
        await widget.controller.toggleTorch();
        if (mounted) setState(() => _on = !_on);
      },
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: AppPalette.ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.no_photography_rounded,
                size: 26,
                color: AppPalette.textTertiary,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                denied ? 'Kamera izni yok.' : 'Kamera açılamadı.',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                denied
                    ? 'Karekod okumak için ayarlardan kamera iznini aç.'
                    : 'Cihazın kamerasına ulaşılamadı.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpace.lg),
              AccentButton(
                label: 'Geri dön',
                expand: false,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
