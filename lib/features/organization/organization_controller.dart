import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/organization_repository.dart';
import '../../domain/availability_slot.dart';
import '../../domain/brand_color.dart';
import '../../domain/org_kind.dart';
import '../../domain/organization.dart';
import '../profile/profile_controller.dart';

/// The signed-in exhibitor's own card, and whether it is live yet.
@immutable
class OrgState {
  const OrgState({this.organization, this.published = false});

  final Organization? organization;

  /// True once the card exists in Firestore. It is the line the stand crosses
  /// from "still choosing" to "assigned for good".
  final bool published;

  bool get isReady => published && (organization?.isComplete ?? false);

  OrgState copyWith({Organization? organization, bool? published}) => OrgState(
    organization: organization ?? this.organization,
    published: published ?? this.published,
  );
}

class OrganizationController extends Notifier<OrgState> {
  @override
  OrgState build() => const OrgState();

  /// Begins a card for a freshly created account.
  ///
  /// [kind] decides what this card will have to answer before it can go live: a
  /// booth and an address for an exhibitor, a stage for a startup.
  void start({
    required String id,
    required String name,
    required String email,
    OrgKind kind = OrgKind.corporate,
  }) {
    state = OrgState(
      organization: Organization(id: id, kind: kind, name: name, email: email),
    );
  }

  /// The startup's own details, collected in one step because they are one
  /// thought: this is my venture, this is what it does, this is where to reach
  /// it. Kept apart from [setIdentity] so it cannot blank the address field an
  /// exhibitor's form owns.
  void setVenture({
    required String name,
    required String description,
    required String email,
    BrandColor? brand,
  }) {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(
      organization: current.copyWith(
        name: name.trim().isEmpty ? null : name.trim(),
        description: description,
        email: email,
        brand: brand,
      ),
    );
  }

  /// How far along the venture is. An empty string clears it, the same way the
  /// sector chips clear themselves when the chosen one is tapped again.
  void setStage(String stage) {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(organization: current.copyWith(stage: stage));
  }

  /// Single-select sector, without touching the fields [setIdentity] owns.
  void setSector(String sector) {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(organization: current.copyWith(sector: sector));
  }

  void setIdentity({
    required String address,
    required String description,
    required BrandColor brand,
    String? sector,
    String? email,
  }) {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(
      organization: current.copyWith(
        address: address,
        description: description,
        brand: brand,
        sector: sector,
        email: email,
      ),
    );
  }

  void setLinks({
    String? website,
    String? instagram,
    String? linkedin,
    String? phone,
  }) {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(
      organization: current.copyWith(
        website: website,
        instagram: instagram,
        linkedin: linkedin,
        phone: phone,
      ),
    );
  }

  void setName(String name) {
    final current = state.organization;
    if (current == null || name.trim().isEmpty) return;
    state = state.copyWith(organization: current.copyWith(name: name.trim()));
  }

  /// Opens a half-hour for meeting requests, replacing any earlier entry for
  /// the same time — an exhibitor cannot be in two places at once.
  void openSlot(AvailabilitySlot slot) {
    final current = state.organization;
    if (current == null) return;
    final next = [
      for (final existing in current.availability)
        if (existing.time != slot.time) existing,
      slot,
    ]..sort((a, b) => a.time.compareTo(b.time));
    state = state.copyWith(organization: current.copyWith(availability: next));
  }

  void closeSlot(String time) {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(
      organization: current.copyWith(
        availability: [
          for (final slot in current.availability)
            if (slot.time != time) slot,
        ],
      ),
    );
  }

  /// Picks the day for a stage talk, or gives the talk up when [day] is null.
  ///
  /// Choosing a day always drops the hour: which hours are still free differs
  /// per day, so carrying one over could leave the company holding a slot
  /// somebody else already has.
  ///
  /// Day and hour are set separately because a day arrives first and an hour
  /// second — a single setter would have to treat "day chosen, hour not yet"
  /// as incomplete and throw the day away.
  void setPanelDay(int? day) {
    final current = state.organization;
    if (current == null) return;
    final cleared = current.copyWith(clearPanel: true);
    state = state.copyWith(
      organization: day == null ? cleared : cleared.copyWith(panelDay: day),
    );
  }

  /// Sets the hour on the day already chosen. Ignored without a day, which the
  /// picker prevents by only showing hours once one is picked.
  void setPanelTime(String time) {
    final current = state.organization;
    if (current == null || current.panelDay == null) return;
    state = state.copyWith(organization: current.copyWith(panelTime: time));
  }

  /// Removes the card and releases the booth.
  ///
  /// Separate from signing out because it is irreversible and outward-facing:
  /// the stand goes grey on every visitor's floor plan the moment it lands.
  Future<void> withdraw() async {
    final organization = state.organization;
    if (organization == null) return;
    await ref.read(organizationRepositoryProvider).withdraw(organization);
    state = const OrgState();
  }

  void setLogo(String base64Jpeg) {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(organization: current.copyWith(logoBase64: base64Jpeg));
  }

  void clearLogo() {
    final current = state.organization;
    if (current == null) return;
    state = state.copyWith(organization: current.copyWith(clearLogo: true));
  }

  /// Selects a booth while still drafting. Refuses once the card is live —
  /// the reservation is permanent, and letting the local draft disagree with
  /// Firestore would only produce a card that lies about where to find the
  /// company.
  void pickStand(String code) {
    final current = state.organization;
    if (current == null || state.published) return;
    state = state.copyWith(organization: current.copyWith(standCode: code));
  }

  void hydrate(Organization organization) =>
      state = OrgState(organization: organization, published: true);

  void reset() => state = const OrgState();

  /// Claims the booth and writes the card. Throws [StandTakenFailure] if the
  /// booth went to someone else while this company was still filling the form.
  Future<void> publish() async {
    final organization = state.organization;
    if (organization == null) {
      throw StateError('Yayına alınacak bir kart yok.');
    }
    await ref.read(organizationRepositoryProvider).publish(organization);
    state = state.copyWith(published: true);
  }

  /// Persists an edit to an already live card.
  void save() {
    final organization = state.organization;
    if (organization == null || !state.published) return;
    ref.read(organizationRepositoryProvider).update(organization);
  }
}

final organizationProvider =
    NotifierProvider<OrganizationController, OrgState>(
      OrganizationController.new,
    );

/// Whether the app's tab shell may be entered.
///
/// The bar differs by audience: a visitor needs interests before the feed means
/// anything, and anyone who publishes a card — exhibitor or founder — needs
/// that card live before there is anything to show. Keeping the rule here
/// rather than on [UserProfile] is what lets it consult the organisation as
/// well as the profile.
final onboardedProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileProvider);
  final role = profile.role;
  if (role == null || !profile.emailVerified) return false;

  return role.publishesCard
      ? ref.watch(organizationProvider).isReady
      : profile.isOnboarded;
});
