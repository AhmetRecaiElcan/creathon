import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/availability_slot.dart';

/// One hour the exhibitor is offering.
///
/// A chip rather than a card: a full day is up to eighteen half-hours, and
/// eighteen cards would bury the meeting requests and the programme under the
/// exhibitor's own calendar. Time and kind are what need to be scannable; the
/// note belongs in the editor, which is one tap away.
class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.slot, required this.onTap});

  final AvailabilitySlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final hasNote = slot.note != null && slot.note!.isNotEmpty;

    return Semantics(
      button: true,
      label: '${slot.time} ${slot.mode.label}. Düzenle',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: accent.withValues(alpha: 0.16),
            border: Border.all(color: accent.withValues(alpha: 0.42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(slot.mode.icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                slot.time,
                style: AppTypography.label.copyWith(fontSize: 13),
              ),
              // A dot rather than the note itself: it says "there is more here"
              // without letting one long note stretch the whole row.
              if (hasNote) ...[
                const SizedBox(width: 5),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The one action that starts the exhibitor's day: open an hour.
class AddAvailabilityButton extends StatelessWidget {
  const AddAvailabilityButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Müsaitlik ekle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: accent.withValues(alpha: 0.24),
            border: Border.all(color: accent.withValues(alpha: 0.62)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: accent),
              const SizedBox(width: 5),
              Text(
                'Saat ekle',
                style: AppTypography.label.copyWith(
                  fontSize: 13,
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
