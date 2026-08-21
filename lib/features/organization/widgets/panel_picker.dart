import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/select_chip.dart';
import '../../../data/organization_repository.dart';
import '../../../domain/panel_slot.dart';
import '../organization_controller.dart';

/// Day and hour for an exhibitor's stage talk.
///
/// The day comes first and the hour second, because which hours are free
/// depends on the day. Hours another exhibitor already booked are shown struck
/// through rather than hidden: a company looking for two o'clock needs to see
/// that two o'clock is gone, not wonder why the list is short.
///
/// Shared between the signup step and the card editor — a talk can be
/// rescheduled after publishing, so both need the same control.
class PanelPicker extends ConsumerWidget {
  const PanelPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationProvider).organization;
    if (organization == null) return const SizedBox.shrink();

    final controller = ref.read(organizationProvider.notifier);
    final taken = ref.watch(takenPanelSlotsProvider);
    final day = organization.panelDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final option in PanelSlots.days)
              SelectChip(
                label: PanelSlots.dayLabel(option),
                selected: day == option,
                onTap: () {
                  // Tapping the chosen day again gives the talk up entirely.
                  controller
                    ..setPanelDay(day == option ? null : option)
                    ..save();
                },
              ),
          ],
        ),
        if (day != null) ...[
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final hour in PanelSlots.hours)
                _HourChip(
                  hour: hour,
                  selected: organization.panelTime == hour,
                  taken:
                      taken.contains('$day-$hour') &&
                      organization.panelTime != hour,
                  onTap: () {
                    controller
                      ..setPanelTime(hour)
                      ..save();
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    required this.hour,
    required this.selected,
    required this.taken,
    required this.onTap,
  });

  final String hour;
  final bool selected;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: taken ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: selected
              ? accent.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: taken ? 0.03 : 0.06),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.65)
                : AppPalette.stroke,
          ),
        ),
        child: Text(
          hour,
          style: AppTypography.label.copyWith(
            fontSize: 13,
            color: taken ? AppPalette.textTertiary : AppPalette.textPrimary,
            decoration: taken ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
