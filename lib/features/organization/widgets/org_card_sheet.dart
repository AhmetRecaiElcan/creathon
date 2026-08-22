import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../data/organization_repository.dart';
import '../../meetings/meeting_request_sheet.dart';
import '../../meetings/meetings_controller.dart';
import '../../profile/profile_controller.dart';
import 'org_card.dart';

/// Opens an exhibitor's card over whatever the user was doing.
///
/// A sheet rather than a route: scanning a stand, tapping a booth on the floor
/// plan and tapping a liked entry are all glances, and none of them should cost
/// the user their place in the list they came from.
Future<void> showOrgCardSheet(
  BuildContext context, {
  required String organizationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _OrgCardSheet(organizationId: organizationId),
  );
}

class _OrgCardSheet extends ConsumerWidget {
  const _OrgCardSheet({required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(organizationByIdProvider(organizationId));
    final profile = ref.watch(profileProvider);
    final liked = profile.likedOrgIds.contains(organizationId);
    final booked = ref.watch(meetingWithProvider(organizationId));

    // Saving a card is for everyone but its owner. A company scanning a
    // founder's card to remember them later is the same act as a visitor
    // keeping a stand — and asking for time is the part that is not: a visitor
    // is here to see the event, so the request belongs to the founder and the
    // fund (see [UserRole.canRequestMeetings]).
    final isOwnCard = profile.uid == organizationId;
    final mayRequest = profile.role?.canRequestMeetings ?? false;
    final offersSlots = organization?.bookableAvailability.isNotEmpty ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: ConstrainedBox(
          // Leaves the top of the screen visible so the sheet reads as
          // something laid over the app rather than as a new screen.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: SingleChildScrollView(
            child: organization == null
                ? const _UnknownOrg()
                : OrgCard(
                    organization: organization,
                    liked: liked,
                    onToggleLike: isOwnCard
                        ? null
                        : () => ref
                              .read(profileProvider.notifier)
                              .toggleLikedOrg(organizationId),
                    bookedLabel: booked == null
                        ? null
                        : '${booked.timeLabel} · ${booked.status.label}',
                    onRequestMeeting: isOwnCard || !mayRequest || !offersSlots
                        ? null
                        : () => showMeetingRequestSheet(
                            context,
                            organization: organization,
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A code that points at an exhibitor this device has never heard of — a stale
/// printout, or a card published while the app was offline.
class _UnknownOrg extends StatelessWidget {
  const _UnknownOrg();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.help_outline_rounded,
            size: 22,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(height: AppSpace.md),
          Text('Kurum bulunamadı.', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Bu kart henüz yayında değil ya da bağlantın kopmuş olabilir.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
