import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/user_role.dart';
import '../profile/profile_controller.dart';

/// The app's front door. Its whole job is to answer "which of the four
/// audiences are you?" before anything else, because every screen after this
/// one is shaped by that answer.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  UserRole? _pending;
  Timer? _navTimer;

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  void _pick(UserRole role) {
    if (_pending != null) return;
    if (!role.isShipped) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppPalette.inkOverlay,
            content: Text(
              '${role.label} deneyimi yakında. Şimdilik ziyaretçi olarak '
              'devam edebilirsin.',
              style: AppTypography.bodySmall.copyWith(
                color: AppPalette.textPrimary,
              ),
            ),
          ),
        );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _pending = role);
    ref.read(profileProvider.notifier).selectRole(role);
    // Hold on this screen while the aurora re-colours, so the role's colour is
    // what carries the user into onboarding rather than arriving after it.
    _navTimer = Timer(const Duration(milliseconds: 640), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: h),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xl,
                    vertical: AppSpace.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Reveal(child: _EventPill()),
                      SizedBox(height: h * 0.11),
                      const Reveal(
                        delay: Duration(milliseconds: 110),
                        child: _Wordmark(),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      Reveal(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          'Etkinlik öncesinden sonrasına uzanan, sana göre '
                          'şekillenen tek deneyim.',
                          style: AppTypography.bodyLarge,
                        ),
                      ),
                      // Sized as a fraction of the viewport so the role grid sits
                      // near the thumb on any phone instead of leaving a void
                      // below it.
                      SizedBox(height: h * 0.21),
                      const Reveal(
                        delay: Duration(milliseconds: 300),
                        child: SectionHeader('NASIL KATILIYORSUN?'),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _RoleGrid(pending: _pending, onPick: _pick),
                      const SizedBox(height: AppSpace.xl),
                      Reveal(
                        delay: const Duration(milliseconds: 780),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppPalette.textTertiary,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                'Rolünü sonra profilinden değiştirebilirsin.',
                                style: AppTypography.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small frosted pill naming the event, so the app identifies itself before the
/// wordmark even lands.
class _EventPill extends StatelessWidget {
  const _EventPill();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: GlassSurface(
        radius: AppRadius.pill,
        blur: 14,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.8), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text('T3 VAKFI  ·  TAKE OFF', style: AppTypography.eyebrow),
          ],
        ),
      ),
    );
  }
}

/// "TakeOff" set as a two-weight lockup: the light "Take" makes the extrabold
/// "Off" read as the emphasis, and the arrow points where the name promises.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFAEB6D8)],
            ).createShader(rect),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Take', style: AppTypography.wordmark.wght(300)),
                  TextSpan(text: 'Off', style: AppTypography.wordmark.wght(800)),
                ],
              ),
              style: AppTypography.wordmark,
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          child: Icon(Icons.north_east_rounded, size: 22, color: accent),
        ),
      ],
    );
  }
}

class _RoleGrid extends StatelessWidget {
  const _RoleGrid({required this.pending, required this.onPick});

  final UserRole? pending;
  final ValueChanged<UserRole> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      mainAxisSpacing: AppSpace.md,
      crossAxisSpacing: AppSpace.md,
      childAspectRatio: 1.06,
      children: [
        for (var i = 0; i < UserRole.values.length; i++)
          Reveal(
            delay: Duration(milliseconds: 380 + i * 80),
            child: _RoleCard(
              role: UserRole.values[i],
              // Null until a pick happens, so nothing is dimmed on arrival.
              selected: pending == null ? null : pending == UserRole.values[i],
              onTap: () => onPick(UserRole.values[i]),
            ),
          ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;

  /// `null` means no choice has been made yet; `false` means another card won.
  final bool? selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isChosen = selected == true;
    final isRejected = selected == false;
    final soon = !role.isShipped;

    return AnimatedOpacity(
      // An unshipped role is dimmed permanently rather than hidden, so the
      // grid still shows the four audiences the platform is built for.
      opacity: isRejected ? 0.35 : (soon ? 0.55 : 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: isChosen ? 1.03 : 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        child: PressableGlass(
          onTap: onTap,
          semanticLabel: '${role.label}. ${role.shortGoal}',
          padding: const EdgeInsets.all(AppSpace.lg),
          tint: role.accent,
          tintOpacity: isChosen ? 0.22 : 0.09,
          borderColor: isChosen
              ? role.accent.withValues(alpha: 0.65)
              : AppPalette.stroke,
          glow: isChosen ? role.accent : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      color: role.accent.withValues(alpha: 0.16),
                      border: Border.all(
                        color: role.accent.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Icon(role.icon, size: 22, color: role.accent),
                  ),
                  const Spacer(),
                  if (soon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: AppPalette.stroke),
                      ),
                      child: Text(
                        'YAKINDA',
                        style: AppTypography.eyebrow.copyWith(
                          fontSize: 8.5,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
              // A fixed gap rather than a Spacer: with a Spacer the label sits on
              // the card's bottom edge, so a one-line goal and a two-line goal
              // push their labels to different heights across the grid.
              const SizedBox(height: AppSpace.lg),
              Text(
                role.label,
                style: AppTypography.titleSmall.wght(700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                role.shortGoal,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12.5,
                  color: AppPalette.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
