import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/section_header.dart';
import '../../data/meeting_repository.dart';
import '../../domain/availability_slot.dart';
import '../../domain/organization.dart';
import '../../domain/user_role.dart';
import '../profile/profile_controller.dart';
import 'meetings_controller.dart';

/// Asks an exhibitor for one of the slots they opened.
///
/// Only offered times are listed, and a time that is gone stays visible with
/// the reason: a grid that silently drops slots reads as arbitrary, while one
/// that says "you already have a meeting then" reads as aware of the day.
Future<void> showMeetingRequestSheet(
  BuildContext context, {
  required Organization organization,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _MeetingRequestSheet(organization: organization),
  );
}

class _MeetingRequestSheet extends ConsumerStatefulWidget {
  const _MeetingRequestSheet({required this.organization});

  final Organization organization;

  @override
  ConsumerState<_MeetingRequestSheet> createState() =>
      _MeetingRequestSheetState();
}

class _MeetingRequestSheetState
    extends ConsumerState<_MeetingRequestSheet> {
  final _note = TextEditingController();

  OrganizationSlot? _chosen;
  bool _busy = false;
  String? _error;
  bool _sent = false;
  Timer? _close;

  @override
  void dispose() {
    _close?.cancel();
    _note.dispose();
    super.dispose();
  }

  /// Whether this card is open all day because it never declared hours.
  ///
  /// A venture keeps no diary — the founder spends the fair walking the hall,
  /// not sitting at a counter — so an empty availability list means "reach me
  /// whenever" rather than "never", and [Organization.bookableAvailability]
  /// turns it into the whole grid. That grid is an implementation detail of
  /// *how* the request gets a time, not a question anyone should be asked: a
  /// wall of half-hours, every one of them open, is a menu with one dish
  /// printed fifty times.
  ///
  /// Tested the same way `bookableAvailability` decides it, not on the kind
  /// alone: a founder who did declare specific hours meant them, and gets a
  /// real grid like anyone else.
  bool get _impliedAllDay =>
      widget.organization.kind.isStartup &&
      widget.organization.availability.isEmpty;

  /// The soonest half-hour free on both sides, or null when there is none.
  static OrganizationSlot? _firstOpen(List<OrganizationSlot> slots) {
    for (final slot in slots) {
      if (slot.available) return slot;
    }
    return null;
  }

  Future<void> _send() async {
    final slots = ref.read(organizationSlotsProvider(widget.organization.id));
    // With no grid there is nothing for the sender to have picked, so the
    // request takes the next opening. `_firstOpen` walks the same list the grid
    // would have drawn, so the slot it lands on has already been checked
    // against the clock and against the sender's own day.
    final slot = _impliedAllDay ? _firstOpen(slots) : _chosen;

    if (slot == null) {
      // "Pick an hour" is only useful advice when there is one to pick. With
      // every offered hour struck through — the day has moved past all of them,
      // or they are all taken — it sends the visitor hunting for something that
      // is not on the screen, which is exactly how this reads as the app being
      // broken rather than the day being over.
      final open = slots.where((slot) => slot.available);
      setState(
        () => _error = open.isEmpty
            ? _impliedAllDay
                  ? 'Bugün için boş yarım saat kalmadı.'
                  : slots.isEmpty
                  ? 'Kurum henüz görüşme saati açmadı.'
                  : 'Kurumun açtığı saatlerin hepsi geçti veya doldu.'
            : 'Bir saat seç.',
      );
      return;
    }

    setState(() {
      // Kept so the confirmation can say which half-hour was actually asked
      // for. The sender was not shown a grid, but they still have to be told
      // what they just booked.
      _chosen = slot;
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(meetingsControllerProvider).request(
        organization: widget.organization,
        start: slot.start,
        end: slot.end,
        mode: slot.mode,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
      // Long enough for the confirmation to be read, short enough that the
      // sheet does not have to be dismissed by hand.
      _close = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    } on SlotTakenFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _chosen = null;
        _error = failure.toString();
      });
    } on MeetingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  /// What the chosen slot commits the sender to, spelled out under the grid:
  /// the half-hour, whether it is a call or a walk, where to walk to, and what
  /// the exhibitor said the slot was for.
  ///
  /// Before anything is chosen it points at the grid — unless the grid has
  /// nothing left to choose, in which case it says so. This sheet can be opened
  /// from a card, which has no way of knowing the day has run out; the picker
  /// list refuses the tap but the card does not, so the sheet has to be able to
  /// explain itself on arrival rather than only after a failed send.
  String _summaryFor(OrganizationSlot? slot, List<OrganizationSlot> slots) {
    if (slot == null) {
      if (slots.every((slot) => !slot.available)) {
        // Worded without pointing at a grid when there is no grid to point at.
        return _impliedAllDay
            ? 'Bugün için boş yarım saat kalmadı.'
            : 'Bu saatlerin hepsi geçti veya doldu — bugün talep gönderilemez.';
      }
      return 'Kurumun açtığı saatler ve görüşme türü yukarıda.';
    }
    final place = switch (slot.mode) {
      MeetingMode.online => 'online görüşme',
      MeetingMode.inPerson => widget.organization.standCode == null
          ? 'yüz yüze, Networking Alanı'
          : 'yüz yüze, Stand ${widget.organization.standCode}',
    };
    final note = slot.note;
    return '${slot.label} – ${slot.offer.endTime} · $place'
        '${note == null || note.isEmpty ? '' : ' · $note'}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final slots = ref.watch(
      organizationSlotsProvider(widget.organization.id),
    );
    final profile = ref.watch(profileProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          bottom: AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
          top: AppSpace.lg,
        ),
        child: GlassSurface(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: _sent
              ? _Sent(
                  accent: accent,
                  slot: _chosen,
                  isInvestor: profile.role == UserRole.investor,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOPLANTI TALEBİ', style: AppTypography.eyebrow),
                    const SizedBox(height: 4),
                    Text(
                      widget.organization.name,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // What the exhibitor will see on the request. Shown before
                    // it is sent, because the sender should never be surprised
                    // by how they were introduced.
                    if (profile.hasInvestorProfile) ...[
                      const SizedBox(height: AppSpace.md),
                      Row(
                        children: [
                          Icon(
                            profile.investorKind!.icon,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                              '${profile.investorLine} olarak gönderilecek.',
                              style: AppTypography.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpace.lg),

                    if (slots.isEmpty)
                      const _NoAvailability()
                    else ...[
                      // No grid for a card that is open all day: there is
                      // nothing to choose between. One line says why instead.
                      if (_impliedAllDay)
                        _AllDayNote(accent: accent)
                      else ...[
                        const SectionHeader('SAAT SEÇ'),
                        const SizedBox(height: AppSpace.md),
                        Wrap(
                          spacing: AppSpace.sm,
                          runSpacing: AppSpace.sm,
                          children: [
                            for (final slot in slots)
                              _SlotChip(
                                slot: slot,
                                selected: _chosen?.label == slot.label,
                                onTap: slot.available
                                    ? () => setState(() {
                                        _chosen = slot;
                                        _error = null;
                                      })
                                    : null,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpace.lg),
                      GlassField(
                        label: 'NOT (İSTEĞE BAĞLI)',
                        hint: 'Neyi görüşmek istiyorsun?',
                        controller: _note,
                        enabled: !_busy,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      SizedBox(
                        height: 34,
                        child: Text(
                          // With no grid the summary carries the whole answer:
                          // it is the only place the sender learns which
                          // half-hour they are about to ask for.
                          _error ??
                              _summaryFor(
                                _chosen ??
                                    (_impliedAllDay
                                        ? _firstOpen(slots)
                                        : null),
                                slots,
                              ),
                          style: AppTypography.bodySmall.copyWith(
                            color: _error == null
                                ? AppPalette.textSecondary
                                : AppPalette.danger,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      AccentButton(
                        label: _busy ? 'Gönderiliyor…' : 'Talebi gönder',
                        icon: _busy ? null : Icons.send_rounded,
                        onPressed: _busy ? null : _send,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// One offered half-hour: the time, and how the meeting would happen.
///
/// The mode is on the chip rather than behind a tap because it changes the
/// answer: an online slot is a call to join from anywhere, an in-person one
/// means being at the booth at that minute. A visitor choosing between two
/// times has to see the difference without opening anything.
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final OrganizationSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final blocked = onTap == null;
    final foreground = blocked
        ? AppPalette.textTertiary
        : AppPalette.textPrimary;

    return Tooltip(
      message: slot.blockedReason ?? slot.note ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected
                ? accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: blocked ? 0.03 : 0.06),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.62)
                  : AppPalette.stroke,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (slot.isPast)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.history_rounded,
                        size: 13,
                        color: AppPalette.textTertiary,
                      ),
                    )
                  else if (blocked)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.block_rounded,
                        size: 13,
                        color: AppPalette.textTertiary,
                      ),
                    )
                  else if (selected)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_rounded, size: 14, color: accent),
                    ),
                  Text(
                    '${slot.label} – ${slot.offer.endTime}',
                    style: AppTypography.label.copyWith(
                      color: foreground,
                      // Struck through only for an hour that has passed, not for
                      // every blocked one: a slot someone else took is still a
                      // real offer for a real time, where this one is the day
                      // having moved on. The two should not look alike.
                      decoration: slot.isPast
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppPalette.textTertiary,
                      decorationThickness: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    slot.mode.icon,
                    size: 12,
                    color: blocked ? AppPalette.textTertiary : accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    slot.mode.label,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: blocked
                          ? AppPalette.textTertiary
                          : AppPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({
    required this.accent,
    required this.slot,
    this.isInvestor = false,
  });

  final Color accent;
  final OrganizationSlot? slot;

  /// Decides which tab the confirmation points at: the investor's requests live
  /// under GÖRÜŞMELER, a visitor's meetings on their agenda.
  final bool isInvestor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, size: 26, color: accent),
        const SizedBox(height: AppSpace.md),
        Text('Talebin gönderildi.', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpace.xs),
        Text(
          isInvestor
              ? '${slot?.label ?? ''} talebin ana sayfanda ve GÖRÜŞMELER '
                    'sekmesinde görünüyor. Kurum onayladığında durumu '
                    'güncellenecek.'
              : '${slot?.label ?? ''} toplantın ana sayfanda ve ajandanda '
                    'görünüyor. Kurum onayladığında durumu güncellenecek.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}

/// Stands in for the grid on a card that is open all day.
///
/// Says why there is nothing to pick. Without it the sheet would be a note
/// field and a send button with no explanation of when the meeting is — and
/// "when" is the one thing a meeting request is made of. The half-hour itself is
/// on the summary line below, so this states the rule and that states the value.
class _AllDayNote extends StatelessWidget {
  const _AllDayNote({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.all_inclusive_rounded, size: 15, color: accent),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Text(
          'Bu girişim gün boyu görüşmeye açık. Talebin en yakın boş yarım '
          'saate gider.',
          style: AppTypography.bodySmall,
        ),
      ),
    ],
  );
}

class _NoAvailability extends StatelessWidget {
  const _NoAvailability();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.event_busy_rounded,
          size: 22,
          color: AppPalette.textTertiary,
        ),
        const SizedBox(height: AppSpace.md),
        Text('Henüz müsait saat yok.', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Bu kurum toplantı saatlerini açtığında buradan talep '
          'gönderebilirsin.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}
