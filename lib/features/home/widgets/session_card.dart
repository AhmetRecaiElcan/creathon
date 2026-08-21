import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/event_session.dart';

/// One agenda row. The time column is fixed-width and left-aligned so a stack
/// of these reads as a schedule at a glance rather than as a list of cards.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.now,
    this.matchedSectors = const [],
    this.saved = false,
    this.onToggleSave,
  });

  final EventSession session;

  /// Whether this session is already on the user's own agenda.
  final bool saved;

  /// Adds or removes the session. Null hides the control entirely, which is
  /// how the agenda's own list stays free of a redundant "remove" affordance
  /// it does not need in every row.
  final VoidCallback? onToggleSave;

  /// Passed in rather than read from the clock so the whole list agrees on what
  /// "now" is and rebuilds consistently.
  final DateTime now;

  /// The user's own interests this session covers, shown as the reason it is on
  /// their agenda at all.
  final List<String> matchedSectors;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final live = session.isLiveAt(now);

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: live ? accent : Colors.white,
      tintOpacity: live ? 0.14 : 0.07,
      borderColor: live ? accent.withValues(alpha: 0.45) : AppPalette.stroke,
      glow: live ? accent : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.startLabel,
                  style: AppTypography.titleSmall.wght(700),
                ),
                const SizedBox(height: 2),
                Text(
                  session.endLabel,
                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Container(
            width: 2,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: live ? 0.9 : 0.5),
                  accent.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      session.kind.icon,
                      size: 13,
                      color: AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      session.kind.label.toUpperCase(),
                      style: AppTypography.eyebrow.copyWith(letterSpacing: 1.2),
                    ),
                    if (live) ...[
                      const SizedBox(width: AppSpace.sm),
                      _LiveBadge(accent: accent),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  session.title,
                  style: AppTypography.titleSmall.copyWith(height: 1.32),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${session.speaker} · ${session.org}',
                  style: AppTypography.bodySmall.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.venue,
                      style: AppTypography.bodySmall.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
                if (matchedSectors.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'İlgi alanın: ${matchedSectors.join(', ')}',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      color: accent.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onToggleSave != null) ...[
            const SizedBox(width: AppSpace.sm),
            _SaveToggle(
              saved: saved,
              accent: accent,
              title: session.title,
              onTap: onToggleSave!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Add-to-agenda control.
///
/// The two states are drawn with different glyphs as well as different colours
/// — a filled accent circle alone would read as "highlighted" rather than as
/// "already added" at a glance down a list.
class _SaveToggle extends StatelessWidget {
  const _SaveToggle({
    required this.saved,
    required this.accent,
    required this.title,
    required this.onTap,
  });

  final bool saved;
  final Color accent;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: saved,
      label: saved ? 'Ajandandan çıkar: $title' : 'Ajandana ekle: $title',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: saved
                ? accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: saved
                  ? accent.withValues(alpha: 0.60)
                  : AppPalette.stroke,
            ),
          ),
          child: Icon(
            saved ? Icons.check_rounded : Icons.add_rounded,
            size: 19,
            color: saved ? accent : AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Pulsing dot plus label for a session that is running right now.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge({required this.accent});

  final Color accent;

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accent,
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.3 + 0.6 * t),
                    blurRadius: 4 + 6 * t,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 5),
        Text(
          'ŞİMDİ',
          style: AppTypography.eyebrow.copyWith(
            color: widget.accent,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
