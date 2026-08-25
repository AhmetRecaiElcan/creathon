import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../data/meeting_brief_repository.dart';
import '../../domain/meeting.dart';
import '../profile/profile_controller.dart';

/// Opens the briefing for a confirmed meeting.
///
/// A sheet rather than a screen: this is read in the two minutes before walking
/// up to a booth, and it has to be dismissable with a thumb without losing the
/// meeting card behind it.
Future<void> showMeetingBriefSheet(
  BuildContext context, {
  required Meeting meeting,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _BriefSheet(meeting: meeting),
  );
}

class _BriefSheet extends ConsumerStatefulWidget {
  const _BriefSheet({required this.meeting});

  final Meeting meeting;

  @override
  ConsumerState<_BriefSheet> createState() => _BriefSheetState();
}

class _BriefSheetState extends ConsumerState<_BriefSheet> {
  BriefResult? _result;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Fetched on open rather than behind a second tap. The button that got the
    // user here already said what it does, and making them confirm it twice
    // would be a round trip's worth of nothing.
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(meetingBriefRepositoryProvider)
          .briefFor(widget.meeting);
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } on BriefFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message;
        _busy = false;
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
        padding: const EdgeInsets.all(AppSpace.lg),
        child: GlassSurface(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
                  const SizedBox(width: AppSpace.sm),
                  Text('GÖRÜŞME BRİFİNGİ', style: AppTypography.eyebrow),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                counterpart,
                style: AppTypography.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.meeting.whenLabel,
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpace.lg),

              // Capped and scrollable: four sections of model prose is taller
              // than a phone on a bad day, and a sheet that overflows loses the
              // part at the bottom rather than the part nobody needed.
              Flexible(
                child: SingleChildScrollView(
                  child: switch ((_result, _error)) {
                    (final BriefResult result, _) => _BriefBody(
                      result: result,
                      accent: accent,
                    ),
                    (_, final String error) => _Failed(
                      message: error,
                      busy: _busy,
                      onRetry: _load,
                    ),
                    _ => _Preparing(accent: accent, counterpart: counterpart),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// While the model is writing.
///
/// Says whose card is being read, because a generic spinner on a sheet that
/// takes two or three seconds reads as a stall rather than as work.
class _Preparing extends StatelessWidget {
  const _Preparing({required this.accent, required this.counterpart});

  final Color accent;
  final String counterpart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  'Brifing hazırlanıyor…',
                  style: AppTypography.titleSmall.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '$counterpart kartı ve senin profilin okunuyor.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// When the model could not be reached.
///
/// A retry rather than a dead end: unlike the ranking, there is no second engine
/// standing behind this one — the only way out is to ask again.
class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.busy,
    required this.onRetry,
  });

  final String message;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(message, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpace.lg),
          Semantics(
            button: true,
            label: 'Tekrar dene',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.md,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: AppPalette.textSecondary.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppPalette.textSecondary.withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  busy ? 'Deneniyor…' : 'Tekrar dene',
                  style: AppTypography.label.copyWith(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The brief itself.
///
/// The order is the order it is useful in: why this is worth the slot, then the
/// three questions — the only part that changes what happens in the room — then
/// what to expect to be asked, then the one thing to bring.
class _BriefBody extends StatelessWidget {
  const _BriefBody({required this.result, required this.accent});

  final BriefResult result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final brief = result.brief;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brief.why.isNotEmpty) ...[
          GlassSurface(
            padding: const EdgeInsets.all(AppSpace.lg),
            tint: accent,
            tintOpacity: 0.12,
            borderColor: accent.withValues(alpha: 0.28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEDEN DEĞERLİ', style: AppTypography.eyebrow),
                const SizedBox(height: AppSpace.sm),
                Text(
                  brief.why,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppPalette.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
        ],

        Text('SORACAKLARIM', style: AppTypography.eyebrow),
        const SizedBox(height: AppSpace.md),
        for (var i = 0; i < brief.questions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.md),
          _Question(index: i + 1, text: brief.questions[i], accent: accent),
        ],

        if (brief.theirAsk.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          _Note(
            label: 'SENDEN NE İSTEYECEK',
            icon: Icons.record_voice_over_outlined,
            text: brief.theirAsk,
          ),
        ],
        if (brief.prep.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          _Note(
            label: 'YANINDA OLSUN',
            icon: Icons.checklist_rounded,
            text: brief.prep,
          ),
        ],

        // Named and hedged, in that order. The reader is about to walk into a
        // room with these questions in their head, and they are entitled to
        // know a model wrote them from two Firestore documents — not a person
        // who has met either party.
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppPalette.textTertiary,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                result.model.isEmpty
                    ? 'Yapay zekâ tarafından, iki tarafın kartından hazırlandı. '
                          'Kontrol etmeden aktarma.'
                    : '${_modelLabel(result.model)} tarafından, iki tarafın '
                          'kartından hazırlandı. Kontrol etmeden aktarma.',
                style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// `Gemini 2.5` — the family, not the revision. The point is which engine.
  static String _modelLabel(String model) {
    final parts = model.split('-').take(2).toList();
    if (parts.isEmpty) return 'Yapay zekâ';
    final name = parts.first;
    final capitalised = name.isEmpty
        ? name
        : name[0].toUpperCase() + name.substring(1);
    return parts.length > 1 ? '$capitalised ${parts[1]}' : capitalised;
  }
}

/// One numbered question.
class _Question extends StatelessWidget {
  const _Question({
    required this.index,
    required this.text,
    required this.accent,
  });

  final int index;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.18),
            border: Border.all(color: accent.withValues(alpha: 0.42)),
          ),
          child: Text(
            '$index',
            style: AppTypography.eyebrow.copyWith(color: accent, fontSize: 10),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppPalette.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// A labelled line of the brief that is not a question.
class _Note extends StatelessWidget {
  const _Note({required this.label, required this.icon, required this.text});

  final String label;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppPalette.textTertiary),
            const SizedBox(width: AppSpace.sm),
            Text(label, style: AppTypography.eyebrow),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          text,
          style: AppTypography.bodySmall.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
