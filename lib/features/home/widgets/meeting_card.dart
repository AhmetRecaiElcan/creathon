import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/meeting.dart';

/// A meeting on the agenda. Shares the time-column layout with [SessionCard] so
/// a mixed timeline still reads as one schedule, but carries the accent fill
/// because this is a commitment the user made rather than a listing.
class MeetingCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
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
                    Icon(
                      meeting.status.icon,
                      size: 12,
                      color: AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      meeting.status.label,
                      style: AppTypography.eyebrow.copyWith(letterSpacing: 0.6),
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
                if (onAccept != null || onDecline != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      if (onAccept != null)
                        Expanded(
                          child: _Action(
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
                          child: _Action(
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

/// Host-side answer button. Outlined rather than filled: two filled buttons
/// side by side would both read as the recommended action.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.label.copyWith(fontSize: 13, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
