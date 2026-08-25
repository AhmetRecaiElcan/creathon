import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/util/clock.dart';
import '../../../data/meeting_link_repository.dart';
import '../../../data/meeting_repository.dart';
import '../../../domain/meeting.dart';
import '../../meetings/meeting_brief_sheet.dart';
import '../../meetings/meeting_feedback_sheet.dart';
import '../../meetings/meetings_controller.dart';

/// A meeting on the agenda. Shares the time-column layout with [SessionCard] so
/// a mixed timeline still reads as one schedule, but carries the accent fill
/// because this is a commitment the user made rather than a listing.
class MeetingCard extends ConsumerWidget {
  const MeetingCard({
    super.key,
    required this.meeting,
    this.asHost = false,
    this.onAccept,
    this.onDecline,
  });

  final Meeting meeting;

  /// True when the exhibitor is looking at a request addressed to them, which
  /// flips which side of the meeting is the headline.
  final bool asHost;

  /// Host-side actions. Absent for a visitor, and for a request that has
  /// already been answered.
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;

    // Both are stored facts now, with no clock in them: a meeting is finished
    // because someone said so, and it can be finished because it was agreed.
    // The clock is read only to word the confirm dialog.
    final awaitsFeedback = meeting.awaitsFeedback;
    final canFinish = meeting.canFinish;

    final headline = asHost ? meeting.requesterName : meeting.organizationName;
    // The host is deciding who to give a slot to, so they get the fund and the
    // kind; the requester already knows who they asked and needs the place.
    final detail = asHost ? meeting.requesterDetail : meeting.location;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: accent,
      tintOpacity: 0.13,
      borderColor: accent.withValues(alpha: 0.38),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.startLabel,
                  style: AppTypography.titleSmall.wght(700),
                ),
                const SizedBox(height: 2),
                Text(
                  meeting.endLabel,
                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Container(
            width: 2,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: accent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.handshake_rounded, size: 13, color: accent),
                    const SizedBox(width: 5),
                    Text(
                      'TOPLANTI',
                      style: AppTypography.eyebrow.copyWith(
                        color: accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    // A meeting that has happened says so on both sides, in
                    // place of the stored status: "Onaylandı" on an hour that
                    // is already behind you tells you nothing you need.
                    Icon(
                      meeting.status.icon,
                      size: 12,
                      color: awaitsFeedback ? accent : AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      meeting.status.label,
                      style: AppTypography.eyebrow.copyWith(
                        letterSpacing: 0.6,
                        color: awaitsFeedback ? accent : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  headline,
                  style: AppTypography.titleSmall.copyWith(height: 1.32),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      asHost ? Icons.person_outline_rounded : Icons.place_outlined,
                      size: 13,
                      color: AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        detail,
                        style: AppTypography.bodySmall.copyWith(fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Day, hour and kind together. The hour alone is on the left
                // column, but an exhibitor deciding whether to accept is asked
                // for a slot on a particular day, in a particular form — and a
                // card that only said "10:00" would leave both open.
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      size: 13,
                      color: AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${meeting.dayLabel}  ·  ${meeting.timeLabel}',
                        style: AppTypography.bodySmall.copyWith(fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(meeting.mode.icon, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      meeting.mode.label,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12.5,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ],
                ),

                // The address stays visible even when the fund takes the line
                // above it: answering a request often means writing back.
                if (asHost &&
                    meeting.requesterEmail != null &&
                    meeting.requesterEmail != detail) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        size: 13,
                        color: AppPalette.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          meeting.requesterEmail!,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (meeting.note != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    '"${meeting.note}"',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Once someone has ended the meeting the only thing left to do
                // is say how it went, so the rating replaces both the join link
                // and the answer buttons rather than sitting alongside them —
                // accepting a meeting that is already over is nonsense, and a
                // call nobody is in is a dead end.
                if (awaitsFeedback) ...[
                  const SizedBox(height: AppSpace.md),
                  _CardAction(
                    label: 'Değerlendir',
                    icon: Icons.star_rounded,
                    color: accent,
                    filled: true,
                    onTap: () =>
                        showMeetingFeedbackSheet(context, meeting: meeting),
                  ),
                ] else ...[
                  // The whole point of an online meeting, and it outranks the
                  // answer buttons below: by the time a room exists the request
                  // has already been accepted, so the first thing to do with
                  // this card is walk into the call.
                  //
                  // It stays here for as long as the meeting is agreed, past
                  // the booked half-hour included. A call that overruns is the
                  // normal case, and taking the link away mid-conversation was
                  // the bug this whole change exists to fix.
                  if (meeting.isJoinable) ...[
                    const SizedBox(height: AppSpace.md),
                    // The name the other side will see is not passed in: the
                    // function picks it from the meeting record by which party
                    // is calling, so the app cannot claim to be someone else.
                    _JoinAction(meeting: meeting, color: accent),
                  ],
                  // Preparation, above the way out and below the way in.
                  //
                  // For a face-to-face meeting this is the only thing on the
                  // card besides "end it", which is the point: a confirmed
                  // booth meeting used to offer nothing but a way to close
                  // something that had not happened yet.
                  if (meeting.canBeBriefed) ...[
                    SizedBox(
                      height: meeting.isJoinable ? AppSpace.sm : AppSpace.md,
                    ),
                    _CardAction(
                      label: 'Brifing al',
                      icon: Icons.auto_awesome_rounded,
                      color: accent,
                      onTap: () =>
                          showMeetingBriefSheet(context, meeting: meeting),
                    ),
                  ],
                  // Either side may end it, and ending it ends it for both:
                  // one person left holding a live join button for a meeting
                  // the other has walked out of is worse than either of them
                  // being asked to confirm. In person there is no link to
                  // follow, so this is the only thing on the card — which is
                  // exactly why it cannot be host-only.
                  //
                  // Sits directly under the join button and on the same
                  // condition, so the way out is never missing where the way in
                  // is offered.
                  if (canFinish) ...[
                    const SizedBox(height: AppSpace.sm),
                    _FinishAction(meeting: meeting),
                  ],
                ],
                if (!awaitsFeedback && (onAccept != null || onDecline != null))
                  ...[
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      if (onAccept != null)
                        Expanded(
                          child: _CardAction(
                            label: 'Onayla',
                            icon: Icons.check_rounded,
                            color: AppPalette.success,
                            onTap: onAccept!,
                          ),
                        ),
                      if (onAccept != null && onDecline != null)
                        const SizedBox(width: AppSpace.sm),
                      if (onDecline != null)
                        Expanded(
                          child: _CardAction(
                            label: 'Reddet',
                            icon: Icons.close_rounded,
                            color: AppPalette.danger,
                            onTap: onDecline!,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ends the meeting for both parties.
///
/// Does its own work through the controller rather than taking a callback,
/// because the two screens that render this card pass different things: the
/// host's home passes accept and decline, the requester's passes nothing at
/// all. Ending belongs to both of them equally, so it cannot be something a
/// parent has to remember to wire up.
///
/// Confirmed first. It cannot be undone from the app — the rating that follows
/// is create-only — and a mis-tap during a live call would take the link away
/// from both people at once.
class _FinishAction extends ConsumerStatefulWidget {
  const _FinishAction({required this.meeting});

  final Meeting meeting;

  @override
  ConsumerState<_FinishAction> createState() => _FinishActionState();
}

class _FinishActionState extends ConsumerState<_FinishAction> {
  bool _busy = false;

  Future<void> _finish() async {
    if (_busy) return;

    // The button is no longer gated on the start time, so a meeting that has
    // not begun can be closed — which is right for two people who talked early,
    // and wrong for a thumb that landed on the wrong card. Nothing stops the
    // second case except saying so here, where it will be read.
    final started = widget.meeting.hasStartedBy(nowOf(ref));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.inkOverlay,
        title: const Text('Görüşmeyi bitir'),
        content: Text(
          started
              ? '${widget.meeting.organizationName} ile görüşme kapanacak ve '
                    'iki taraf da değerlendirme yapabilecek. Geri alınamaz.'
              : 'Bu görüşme henüz başlamadı '
                    '(${widget.meeting.whenLabel}). Yine de kapatırsan iki '
                    'taraf da değerlendirme yapabilecek ve geri alınamaz.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(meetingsControllerProvider).finish(widget.meeting);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      // The repository already says why in words worth reading — a refused
      // write and a dropped connection send whoever is looking to two different
      // places, and flattening them into "check your connection" sends both to
      // the wrong one.
      final message = error is MeetingFailure
          ? error.message
          : 'Görüşme bitirilemedi. Bağlantını kontrol edip tekrar dene.';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppPalette.inkOverlay,
            content: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppPalette.textPrimary,
              ),
            ),
          ),
        );
      return;
    }
    // No setState on success: the meeting's status change flows back through
    // the stream and this widget goes away with the button.
  }

  @override
  Widget build(BuildContext context) => _CardAction(
    label: _busy ? 'Bitiriliyor…' : 'Görüşmeyi bitir',
    icon: Icons.stop_circle_outlined,
    color: AppPalette.textSecondary,
    onTap: _busy ? () {} : _finish,
  );
}

/// Opens the video room for a confirmed online meeting.
///
/// Filled and full width, unlike the outlined answer buttons: there is exactly
/// one thing to do with a call that is already agreed, and a card that made the
/// user hunt for it would be the worst moment in the app to be subtle.
///
/// The tap is a round trip, not a link: the room admits whoever holds a signed
/// token, and only the server can sign one. So the button has a waiting state,
/// short as it is — a filled button that appeared to do nothing for a second
/// would be tapped again, and again.
class _JoinAction extends ConsumerStatefulWidget {
  const _JoinAction({required this.meeting, required this.color});

  final Meeting meeting;
  final Color color;

  @override
  ConsumerState<_JoinAction> createState() => _JoinActionState();
}

class _JoinActionState extends ConsumerState<_JoinAction> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? failure;

    try {
      final url = await ref
          .read(meetingLinkRepositoryProvider)
          .linkFor(widget.meeting);

      // Externally rather than in a web view: the call needs the camera and
      // the microphone, and an in-app view is where those permissions go to
      // die. The browser — or the Jitsi app, if it is installed and claims the
      // link — already knows how to ask for them.
      final opened = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        failure = 'Görüşme açılamadı. Tarayıcın engelliyor olabilir.';
      }
    } on JoinLinkFailure catch (error) {
      // The function says why in words the user can act on, so its own message
      // is shown rather than a generic one.
      failure = error.message;
    } catch (_) {
      failure = 'Görüşme açılamadı. Bağlantını kontrol edip tekrar dene.';
    }

    if (!mounted) return;
    setState(() => _busy = false);
    if (failure == null) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppPalette.inkOverlay,
          content: Text(
            failure,
            style: AppTypography.bodySmall.copyWith(
              color: AppPalette.textPrimary,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Görüşmeye katıl',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : _open,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: widget.color.withValues(alpha: _busy ? 0.5 : 0.9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_busy)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppPalette.ink,
                  ),
                )
              else
                const Icon(
                  Icons.videocam_rounded,
                  size: 17,
                  color: AppPalette.ink,
                ),
              const SizedBox(width: 7),
              Text(
                _busy ? 'Bağlanıyor…' : 'Görüşmeye katıl',
                style: AppTypography.label.copyWith(
                  fontSize: 13.5,
                  color: AppPalette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A button on the card.
///
/// Outlined by default: the accept/decline pair sits side by side, and two
/// filled buttons would both read as the recommended action. [filled] is for
/// the cases where there is only one thing to do — rating a finished meeting —
/// and being subtle about it would just make it hard to find.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppPalette.ink : color;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: color.withValues(alpha: filled ? 0.9 : 0.14),
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  fontSize: 13,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
