import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../domain/organization.dart';

/// The exhibitor's info card.
///
/// One widget serves three places on purpose — the company's own screen, the
/// sheet a scan opens, and the agenda's liked list. What a visitor sees after
/// scanning must be exactly what the company thinks it published, and the only
/// way to guarantee that is to render it from the same code.
class OrgCard extends StatelessWidget {
  const OrgCard({
    super.key,
    required this.organization,
    this.liked,
    this.onToggleLike,
    this.showLinks = true,
    this.onRequestMeeting,
    this.bookedLabel,
    this.onEditChannel,
  });

  final Organization organization;

  /// Null for the company looking at its own card, where liking is meaningless.
  final bool? liked;
  final VoidCallback? onToggleLike;

  final bool showLinks;

  /// Opens the meeting request sheet. Null for the company's own card, and
  /// for an exhibitor that has not opened any slots.
  final VoidCallback? onRequestMeeting;

  /// Set when this visitor already has a meeting with the exhibitor, which
  /// replaces the request action with its outcome.
  final String? bookedLabel;

  /// Set only on the owner's own preview: puts a pencil beside each channel so
  /// a wrong handle can be fixed where it is noticed, rather than from a form
  /// somewhere else.
  final ValueChanged<OrgChannel>? onEditChannel;

  @override
  Widget build(BuildContext context) {
    final color = organization.color;
    final links = organization.links;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      tint: color,
      tintOpacity: 0.14,
      borderColor: color.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrgLogo(organization: organization, size: 56),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (organization.standCode != null)
                      Text(
                        'STAND ${organization.standCode}'
                        '${organization.sectorLabel == null ? '' : '  ·  ${organization.sectorLabel}'}',
                        style: AppTypography.eyebrow.copyWith(color: color),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      organization.name.isEmpty
                          ? 'Adsız kurum'
                          : organization.name,
                      style: AppTypography.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onToggleLike != null) ...[
                const SizedBox(width: AppSpace.sm),
                _LikeButton(
                  liked: liked ?? false,
                  color: color,
                  onTap: onToggleLike!,
                ),
              ],
            ],
          ),

          if (organization.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text(
              organization.description,
              style: AppTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ],

          if (organization.address.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: AppPalette.textTertiary,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    organization.address,
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ],

          if (bookedLabel != null) ...[
            const SizedBox(height: AppSpace.lg),
            _MeetingState(label: bookedLabel!, color: color),
          ] else if (onRequestMeeting != null) ...[
            const SizedBox(height: AppSpace.lg),
            _MeetingAction(color: color, onTap: onRequestMeeting!),
          ],

          if (showLinks && links.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Container(height: 1, color: AppPalette.stroke),
            const SizedBox(height: AppSpace.sm),
            for (final link in links)
              _LinkRow(
                link: link,
                color: color,
                onEdit: onEditChannel == null
                    ? null
                    : () => onEditChannel!(link.channel),
              ),
          ],
        ],
      ),
    );
  }
}

/// The logo slot, falling back to the company's initials on the brand colour.
class OrgLogo extends StatelessWidget {
  const OrgLogo({
    super.key,
    required this.organization,
    this.size = 48,
    this.radius,
  });

  final Organization organization;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final logo = organization.logoBase64;
    final color = organization.color;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? AppRadius.sm),
        color: color.withValues(alpha: 0.22),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: logo == null || logo.isEmpty
          ? _initials()
          : Image.memory(
              base64Decode(logo),
              width: size,
              height: size,
              fit: BoxFit.cover,
              // A corrupt string must not take the card down with it.
              errorBuilder: (_, _, _) => _initials(),
            ),
    );
  }

  Widget _initials() => Text(
    organization.initials,
    style: AppTypography.titleMedium.copyWith(fontSize: size * 0.36),
  );
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.color,
    required this.onTap,
  });

  final bool liked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: liked,
      label: liked ? 'Ajandandan çıkar' : 'Ajandana ekle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: liked
                ? color.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: liked ? color.withValues(alpha: 0.62) : AppPalette.stroke,
            ),
          ),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 19,
            color: liked ? color : AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One tappable channel. Failure is reported rather than swallowed: a visitor
/// who taps Instagram and sees nothing happen has no way to tell whether the
/// company published a broken handle or the app is broken.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.color,
    required this.onEdit,
  });

  final OrgLink link;
  final Color color;

  /// Owner-only. Null for everyone else, which leaves the row read-only.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(link.url);
        var opened = false;
        if (uri != null) {
          try {
            opened = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {
            opened = false;
          }
        }
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppPalette.inkOverlay,
                content: Text(
                  '${link.label} açılamadı.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
            );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Row(
          children: [
            Icon(link.icon, size: 17, color: color),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.label.toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(fontSize: 9.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.display,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppPalette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.north_east_rounded,
              size: 15,
              color: AppPalette.textTertiary,
            ),
            if (onEdit != null) ...[
              const SizedBox(width: AppSpace.lg),
              Semantics(
                button: true,
                label: '${link.label} düzenle',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Icon(Icons.edit_outlined, size: 17, color: color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one action a visitor can take on someone else's card beyond keeping it.
class _MeetingAction extends StatelessWidget {
  const _MeetingAction({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Toplantı talep et',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: color.withValues(alpha: 0.20),
            border: Border.all(color: color.withValues(alpha: 0.52)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handshake_rounded, size: 17, color: color),
              const SizedBox(width: AppSpace.sm),
              Text(
                'Toplantı talep et',
                style: AppTypography.label.copyWith(
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

/// Replaces the action once a meeting exists, so the card never invites a
/// second request for a time the visitor already holds.
class _MeetingState extends StatelessWidget {
  const _MeetingState({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: AppPalette.stroke),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 17, color: color),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppPalette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
