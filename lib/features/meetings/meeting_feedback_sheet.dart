import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/glass_surface.dart';
import '../../data/meeting_feedback_repository.dart';
import '../../domain/meeting.dart';
import '../../domain/meeting_feedback.dart';
import '../profile/profile_controller.dart';
import 'meetings_controller.dart';

/// Asks how a finished meeting went.
///
/// Opens on the meeting being over, and closing it is what retires the meeting
/// from this person's screens — so the sheet is the last thing they see of it,
/// and it has to say who and when without them having to remember.
Future<void> showMeetingFeedbackSheet(
  BuildContext context, {
  required Meeting meeting,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _FeedbackSheet(meeting: meeting),
  );
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet({required this.meeting});

  final Meeting meeting;

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final _note = TextEditingController();

  /// Nothing preselected. A sheet that opens on five stars is a sheet that
  /// collects five stars, because the fastest way out is to send what is
  /// already there.
  int _rating = 0;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    if (!MeetingFeedback.isValidRating(_rating)) {
      setState(() => _error = 'Bir yıldız seç.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(meetingsControllerProvider)
          .submitFeedback(
            meeting: widget.meeting,
            rating: _rating,
            note: _note.text,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });

      // Long enough to read the confirmation, short enough that it does not
      // feel stuck. The meeting is already gone from the list behind this.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) Navigator.of(context).maybePop();
    } on FeedbackFailure catch (failure) {
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
    final uid = ref.watch(profileProvider).uid;
    final asHost = widget.meeting.organizationId == uid;
    final counterpart = asHost
        ? widget.meeting.requesterName
        : widget.meeting.organizationName;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          top: AppSpace.lg,
          bottom: AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: GlassSurface(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: _sent
              ? _Landed(accent: accent, counterpart: counterpart)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GÖRÜŞME TAMAMLANDI', style: AppTypography.eyebrow),
                    const SizedBox(height: 4),
                    Text(
                      counterpart,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      children: [
                        Icon(
                          widget.meeting.mode.icon,
                          size: 13,
                          color: AppPalette.textTertiary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.meeting.whenLabel,
                            style: AppTypography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'Görüşme nasıl geçti?',
                      style: AppTypography.label.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: AppSpace.md),
                    _Stars(
                      rating: _rating,
                      accent: accent,
                      onPick: (value) => setState(() {
                        _rating = value;
                        _error = null;
                      }),
                    ),

                    const SizedBox(height: AppSpace.lg),
                    GlassField(
                      controller: _note,
                      label: 'Açıklama (isteğe bağlı)',
                      hint: 'Ne konuşuldu, ne çıktı?',
                      maxLines: 4,
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 15,
                            color: AppPalette.danger,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppPalette.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpace.lg),
                    // Said before the button, not after: sending is what
                    // retires the meeting, and that is not obviously
                    // reversible-looking enough to leave unsaid.
                    Text(
                      'Gönderdiğinde bu görüşme listenden kalkar ve '
                      'değerlendirme bir daha değiştirilemez.',
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: AppSpace.md),
                    AccentButton(
                      label: _busy ? 'Gönderiliyor…' : 'Değerlendirmeyi gönder',
                      icon: Icons.star_rounded,
                      onPressed: _busy ? null : _send,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The five stars. Tapping one selects it and everything before it, which is
/// what a rating means — three stars is not "the third star".
class _Stars extends StatelessWidget {
  const _Stars({
    required this.rating,
    required this.accent,
    required this.onPick,
  });

  final int rating;
  final Color accent;
  final ValueChanged<int> onPick;

  static const _labels = {
    1: 'Hiç verimli değildi',
    2: 'Zayıf',
    3: 'İdare eder',
    4: 'Verimliydi',
    5: 'Çok verimliydi',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var star = 1; star <= MeetingFeedback.maxRating; star++)
              Semantics(
                button: true,
                selected: star <= rating,
                label: '$star yıldız',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: Icon(
                      star <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 34,
                      color: star <= rating ? accent : AppPalette.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Reserved whether or not a star is chosen, so picking one does not
        // shove the rest of the sheet down.
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Text(
            _labels[rating] ?? 'Beş yıldız üzerinden puanla',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12.5,
              color: rating == 0 ? AppPalette.textTertiary : accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// The confirmation, shown for a moment before the sheet closes itself.
class _Landed extends StatelessWidget {
  const _Landed({required this.accent, required this.counterpart});

  final Color accent;
  final String counterpart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, size: 34, color: accent),
        const SizedBox(height: AppSpace.md),
        Text('Değerlendirmen kaydedildi', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpace.xs),
        Text(
          '$counterpart ile görüşmen tamamlandı ve listenden kaldırıldı.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}
