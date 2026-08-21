import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/section_header.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization.dart';
import '../../domain/user_role.dart';
import '../organization/widgets/org_row.dart';
import '../profile/profile_controller.dart';
import 'meeting_request_sheet.dart';
import 'meetings_controller.dart';

/// "Who do you want to meet?" — the step before the request itself.
///
/// An investor standing in the hall reaches a company by scanning its stand or
/// tapping its booth, but the work also happens on the train home, and there a
/// list is the only way in. Companies whose hours are open come first: the list
/// is sorted by what can actually be booked, not alphabetically.
Future<void> showOrgPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _OrgPickerSheet(),
  );
}

class _OrgPickerSheet extends ConsumerWidget {
  const _OrgPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final sectors = profile.sectors;
    final startups = _ordered(ref.watch(startupsProvider), sectors);
    final exhibitors = _ordered(ref.watch(exhibitorsProvider), sectors);
    final isEmpty = startups.isEmpty && exhibitors.isEmpty;

    // Whoever the reader came for goes on top: an investor is here for the
    // ventures, a founder for the companies.
    final startupsFirst = profile.role == UserRole.investor;
    final sections = [
      if (startupsFirst) ...[
        ('GİRİŞİMLER', startups),
        ('KURUMLAR', exhibitors),
      ] else ...[
        ('KURUMLAR', exhibitors),
        ('GİRİŞİMLER', startups),
      ],
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: GlassSurface(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GÖRÜŞME TALEBİ', style: AppTypography.eyebrow),
                const SizedBox(height: 4),
                Text('Kimle görüşeceksin?', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(
                  isEmpty
                      ? 'Kurumlar ve girişimler kartlarını yayına aldığında '
                            'burada listelenir.'
                      : 'Saatlerini açanlar üstte. Bir isme dokunduğunda '
                            'açtığı saatler listelenir.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                if (isEmpty)
                  const _NoOrganizations()
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (title, group) in sections)
                            if (group.isNotEmpty) ...[
                              SectionHeader(
                                title,
                                trailing: Text(
                                  '${group.length}',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpace.md),
                              for (final organization in group)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpace.md,
                                  ),
                                  child: _PickerRow(
                                    organization: organization,
                                  ),
                                ),
                              const SizedBox(height: AppSpace.sm),
                            ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bookable first, then the ones matching the investor's own thesis, then the
  /// rest by name. Nothing is filtered out — a company with no hours open is
  /// still worth knowing is here.
  static List<Organization> _ordered(
    List<Organization> all,
    Set<String> sectors,
  ) {
    final ordered = [...all];
    ordered.sort((a, b) {
      final open = (b.availability.isNotEmpty ? 1 : 0).compareTo(
        a.availability.isNotEmpty ? 1 : 0,
      );
      if (open != 0) return open;

      final matched = (sectors.contains(b.sectorLabel) ? 1 : 0).compareTo(
        sectors.contains(a.sectorLabel) ? 1 : 0,
      );
      if (matched != 0) return matched;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return ordered;
  }
}

class _PickerRow extends ConsumerWidget {
  const _PickerRow({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final booked = ref.watch(meetingWithProvider(organization.id));
    final open = organization.availability.length;

    // Three states, and each one has to say what it is: already asked, open for
    // a request, or closed. Only the middle one is tappable.
    final String caption;
    final Widget trailing;
    final bool enabled;

    if (booked != null) {
      caption = '${booked.timeLabel}  ·  ${booked.status.label}';
      trailing = Icon(booked.status.icon, size: 18, color: accent);
      enabled = false;
    } else if (open == 0) {
      caption = 'Henüz görüşme saati açmadı';
      trailing = const Icon(
        Icons.event_busy_rounded,
        size: 18,
        color: AppPalette.textTertiary,
      );
      enabled = false;
    } else {
      // For a startup the stage is what decides whether the meeting is worth
      // asking for, so it takes the place the sector holds on a company's row.
      final detail = organization.kind.isStartup
          ? organization.stageLabel ?? organization.sectorLabel
          : organization.sectorLabel;
      caption = detail == null ? '$open saat açık' : '$open saat açık  ·  $detail';
      trailing = const Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: AppPalette.textTertiary,
      );
      enabled = true;
    }

    return OrgRow(
      organization: organization,
      caption: caption,
      trailing: trailing,
      enabled: enabled,
      onTap: enabled
          ? () {
              // The picker closes first: coming back from a sent request to a
              // list of companies would read as though nothing happened. The
              // navigator's own context is what opens the next sheet — this
              // row's context is gone the moment the pop lands.
              final navigator = Navigator.of(context);
              navigator.pop();
              showMeetingRequestSheet(
                navigator.context,
                organization: organization,
              );
            }
          : null,
    );
  }
}

class _NoOrganizations extends StatelessWidget {
  const _NoOrganizations();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.storefront_outlined,
          size: 20,
          color: AppPalette.textTertiary,
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text(
            'Yayında kurum yok. Fuar alanındaki standlardan ya da karekod '
            'okutarak da ulaşabilirsin.',
            style: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }
}
