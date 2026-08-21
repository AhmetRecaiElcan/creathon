import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'glass_surface.dart';

@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.branch,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Which shell branch this slot opens.
  ///
  /// Not the same as the slot's position: the branches are a fixed list shared
  /// by every audience, while the bar shows a different subset in a different
  /// order per role. Naming the branch here is what lets the investor's second
  /// tab be the fifth branch without the other portfolios growing a tab.
  final int branch;
}

/// Floating frosted tab bar.
///
/// Inset from the edges rather than pinned flush to the bottom, so the aurora
/// stays visible around it and the bar reads as another pane floating on the
/// background rather than as chrome bolted to the frame.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.md,
      ),
      child: GlassSurface(
        radius: AppRadius.lg,
        blur: 28,
        tintOpacity: 0.11,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  accent: accent,
                  onTap: () {
                    if (i == currentIndex) return;
                    HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected
                ? accent.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 21,
                color: selected ? accent : AppPalette.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: AppTypography.eyebrow.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 0.6,
                  color: selected ? accent : AppPalette.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
