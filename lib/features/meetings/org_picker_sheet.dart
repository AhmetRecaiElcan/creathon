import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_surface.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization.dart';
import '../organization/widgets/org_row.dart';
import '../profile/profile_controller.dart';
import 'meeting_request_sheet.dart';
import 'meetings_controller.dart';

/// "Who do you want to meet?" — the step before the request itself.
///
/// An investor standing in the hall reaches a company by scanning its stand or
/// tapping its booth, but the work also happens on the train home, and there a
/// list is the only way in. Cards whose hours are open come first: the list is
/// sorted by what can actually be booked, not alphabetically.
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

    // Every published card, company and venture alike: a fund comes to the
    // fair for the ventures at least as much as for the corporates, so a list
    // that showed only exhibitors would hide the half it came for. Own card
    // dropped — asking yourself for a meeting is not a state worth having.
    final cards = _ordered(
      ref
          .watch(organizationsProvider)
          .where((organization) => organization.id != profile.uid)
          .toList(growable: false),
      profile.sectors,
    );

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
                Text('Kiminle görüşeceksin?', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(
                  cards.isEmpty
                      ? 'Kurumlar ve girişimler kartlarını yayına aldığında '
                            'burada listelenir.'
                      : 'Saatleri açık olanlar üstte. Bir karta dokunduğunda '
                            'açık saatler ve görüşme türü listelenir.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                if (cards.isEmpty)
                  const _NoOrganizations()
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: cards.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpace.md),
                      itemBuilder: (_, index) =>
                          _PickerRow(organization: cards[index]),
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
      final open = (b.bookableAvailability.isNotEmpty ? 1 : 0).compareTo(
        a.bookableAvailability.isNotEmpty ? 1 : 0,
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

    // Counted off the same grid the request sheet renders, rather than off the
    // declared hours: a card that promises "18 saat açık" at five in the
    // afternoon is a card that lies, and the visitor finds out only after
    // tapping through to a sheet of struck-through times.
    final slots = ref.watch(organizationSlotsProvider(organization.id));
    final open = slots.where((slot) => slot.available).length;

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
      // Two different nothings, and saying the wrong one is misleading: a card
      // that never opened hours may open some, where a day that has run out
      // will not come back today.
      caption = slots.isEmpty
          ? 'Henüz görüşme saati açmadı'
          : 'Bugünün saatleri doldu';
      trailing = const Icon(
        Icons.event_busy_rounded,
        size: 18,
        color: AppPalette.textTertiary,
      );
      enabled = false;
    } else {
      // What the row has to answer before a tap: how many hours, and of what
      // kind — walking to a booth and joining a call are different plans.
      final modes = {
        for (final slot in slots.where((slot) => slot.available)) slot.mode,
      };
      final kinds = modes.map((mode) => mode.label).join(' / ');
      caption = '$open saat açık  ·  $kinds';
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
            'Yayında kart yok. Fuar alanındaki standlardan ya da karekod '
            'okutarak da ulaşabilirsin.',
            style: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }
}
