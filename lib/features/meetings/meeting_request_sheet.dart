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

  Future<void> _send() async {
    final slot = _chosen;
    if (slot == null) {
      setState(() => _error = 'Bir saat seç.');
      return;
    }

    setState(() {
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

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final slots = ref.watch(
      organizationSlotsProvider(widget.organization.id),
    );
    final profile = ref.watch(profileProvider);

    return SafeArea(
      child: Padding
      (
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
                        height: 22,
                        child: Text(
                          _error ??
                              (_chosen == null
                                  ? 'Kurumun açtığı saatler listelendi.'
                                  : '${_chosen!.label} için talep '
                                        'göndereceksin.'),
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

    return Tooltip(
      message: slot.blockedReason ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: selected
                ? accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: blocked ? 0.03 : 0.06),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.62)
                  : AppPalette.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blocked)
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
                slot.label,
                style: AppTypography.label.copyWith(
                  color: blocked
                      ? AppPalette.textTertiary
                      : AppPalette.textPrimary,
                ),
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
