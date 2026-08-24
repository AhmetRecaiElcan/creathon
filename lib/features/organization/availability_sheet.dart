import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/util/clock.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/availability_slot.dart';
import 'organization_controller.dart';

/// Opens a half-hour for meeting requests.
///
/// The exhibitor is making an offer, not filling a calendar, so all three parts
/// of the offer are here at once: when, how, and what for. Editing an existing
/// slot reuses the same sheet with [existing] filled in.
Future<void> showAvailabilitySheet(
  BuildContext context, {
  AvailabilitySlot? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AvailabilitySheet(existing: existing),
  );
}

class _AvailabilitySheet extends ConsumerStatefulWidget {
  const _AvailabilitySheet({this.existing});

  final AvailabilitySlot? existing;

  @override
  ConsumerState<_AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends ConsumerState<_AvailabilitySheet> {
  final _note = TextEditingController();

  String? _time;
  MeetingMode _mode = MeetingMode.inPerson;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _time = existing.time;
    _mode = existing.mode;
    _note.text = existing.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final time = _time;
    if (time == null) {
      setState(() => _error = 'Bir saat seç.');
      return;
    }

    ref.read(organizationProvider.notifier)
      ..openSlot(
        AvailabilitySlot(time: time, mode: _mode, note: _note.text),
      )
      ..save();
    Navigator.of(context).maybePop();
  }

  void _close() {
    final existing = widget.existing;
    if (existing == null) return;
    ref.read(organizationProvider.notifier)
      ..closeSlot(existing.time)
      ..save();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(organizationProvider).organization;
    if (organization == null) return const SizedBox.shrink();

    // An hour already open cannot be opened twice — except the one being
    // edited, which has to stay selectable.
    final taken = organization.openTimes.difference({
      if (widget.existing != null) widget.existing!.time,
    });

    // Hours that have already gone by today.
    //
    // The grid covers the whole clock, so at nine in the morning its first six
    // chips are the middle of the night — and an exhibitor reasonably reading
    // the first chips as "the start of the day" would open hours that are dead
    // the moment they are saved: every visitor sees them struck through and
    // nobody can ask for one. This is the same cut-off the request sheet uses
    // (`OrganizationSlot.isPast`), applied here so the offer cannot be made in
    // the first place rather than only refused afterwards.
    //
    // The slot being edited stays tappable even when past: it is already the
    // exhibitor's own, and locking them out of their own row would leave no way
    // to change its kind or note.
    // Closed at the half-hour's *end*, matching the grid the requester sees: at
    // 12:10 the 12:00 slot is still running and still worth offering.
    final now = ref.watch(clockProvider);
    final past = <String>{
      for (final label in SlotGrid.labels)
        if (label != widget.existing?.time &&
            !(AvailabilitySlot(time: label)
                    .parseOn(now)
                    ?.add(const Duration(minutes: 30))
                    .isAfter(now) ??
                true))
          label,
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          top: AppSpace.lg,
          bottom: AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: GlassSurface(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existing == null
                        ? 'MÜSAİTLİK EKLE'
                        : 'MÜSAİTLİĞİ DÜZENLE',
                    style: AppTypography.eyebrow,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ziyaretçiler yalnızca açtığın saatler için talep '
                    'gönderebilir.',
                    style: AppTypography.bodySmall,
                  ),

                  const SizedBox(height: AppSpace.lg),
                  const SectionHeader('SAAT'),
                  const SizedBox(height: AppSpace.md),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final label in SlotGrid.labels)
                        _TimeChip(
                          label: label,
                          selected: _time == label,
                          taken: taken.contains(label),
                          isPast: past.contains(label),
                          onTap: () => setState(() {
                            _time = label;
                            _error = null;
                          }),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpace.lg),
                  const SectionHeader('TOPLANTI TÜRÜ'),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      for (final mode in MeetingMode.values) ...[
                        if (mode != MeetingMode.values.first)
                          const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: _ModeChip(
                            mode: mode,
                            selected: _mode == mode,
                            onTap: () => setState(() => _mode = mode),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: AppSpace.lg),
                  GlassField(
                    label: 'AÇIKLAMA (İSTEĞE BAĞLI)',
                    hint: _mode == MeetingMode.online
                        ? 'Görüşme bağlantısını onayladıktan sonra paylaş'
                        : 'Ne konuşmak istiyorsun?',
                    controller: _note,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),

                  const SizedBox(height: AppSpace.lg),
                  SizedBox(
                    height: 22,
                    child: Text(
                      _error ??
                          (_time == null
                              ? 'Dolu saatler seçilemez.'
                              : '$_time · ${_mode.label}'),
                      style: AppTypography.bodySmall.copyWith(
                        color: _error == null
                            ? AppPalette.textSecondary
                            : AppPalette.danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  AccentButton(
                    label: widget.existing == null ? 'Ekle' : 'Kaydet',
                    icon: Icons.check_rounded,
                    onPressed: _save,
                  ),
                  // Closing an hour lives here rather than on the chip: the
                  // chip has to stay small enough that a full day of them fits
                  // above the meeting requests.
                  if (widget.existing != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    Center(
                      child: TextButton.icon(
                        onPressed: _close,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Bu saati kapat'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.danger,
                          textStyle: AppTypography.label,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.taken,
    required this.onTap,
    this.isPast = false,
  });

  final String label;
  final bool selected;
  final bool taken;

  /// Already gone by. Kept in the grid rather than filtered out for the same
  /// reason the requester's sheet keeps them: a grid that silently shortened
  /// through the day would read as the app losing hours, not as time passing.
  final bool isPast;

  final VoidCallback onTap;

  /// Open already or gone already — both mean "not offerable", and both are
  /// drawn the same way. They differ only in why, and the time itself says
  /// which: a struck-through 00:30 at nine in the morning explains itself.
  bool get _closed => taken || isPast;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: _closed ? null : onTap,
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
              : Colors.white.withValues(alpha: _closed ? 0.03 : 0.06),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.65)
                : AppPalette.stroke,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            fontSize: 13,
            color: _closed ? AppPalette.textTertiary : AppPalette.textPrimary,
            decoration: _closed ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MeetingMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: selected
              ? accent.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.60)
                : AppPalette.stroke,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mode.icon,
              size: 16,
              color: selected ? accent : AppPalette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              mode.label,
              style: AppTypography.label.copyWith(
                fontSize: 13,
                color: selected
                    ? AppPalette.textPrimary
                    : AppPalette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
