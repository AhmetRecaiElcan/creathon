import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../data/auth_repository.dart';
import '../../data/meeting_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/meeting.dart';
import '../meetings/meetings_controller.dart';
import '../organization/organization_controller.dart';
import 'profile_controller.dart';

/// Tears an account down completely.
///
/// Deleting a user from the Firebase console reaches Auth and nothing else —
/// there is no hook a client can observe, so the documents it owned would sit
/// there forever and an exhibitor's booth would stay coloured on the floor plan
/// for a company that no longer exists. The only way to keep the two in step
/// without Cloud Functions is for the app to own the whole teardown, in this
/// order: the data first, the account last, so a failure never strands an
/// account with no way back in to clean up after itself.
class AccountDeletion {
  const AccountDeletion(this._ref);

  final Ref _ref;

  /// Removes the account's own profile document and the account itself.
  ///
  /// Also used by the investor, whose record is the same shape — a user
  /// document and the requests they sent.
  Future<void> deleteVisitor() async {
    await _cancelMeetings();

    final uid = _ref.read(profileProvider).uid;
    if (uid != null) {
      await _ref.read(profileRepositoryProvider).delete(uid);
    }
    await _ref.read(authRepositoryProvider).deleteAccount();
    _ref.read(profileProvider.notifier).reset();
  }

  /// Removes a published card, releases its booth if it holds one, then removes
  /// the account.
  ///
  /// Serves the founder as well as the exhibitor: the card and the booth lock go
  /// together in one batch, so the floor plan can never show a stand with no
  /// card behind it, and a startup simply has no lock to release.
  Future<void> deleteCorporate() async {
    await _cancelMeetings();
    await _ref.read(organizationProvider.notifier).withdraw();

    final uid = _ref.read(profileProvider).uid;
    if (uid != null) {
      await _ref.read(profileRepositoryProvider).delete(uid);
    }
    await _ref.read(authRepositoryProvider).deleteAccount();
    _ref.read(profileProvider.notifier).reset();
  }

  /// Drops every meeting this account is a party to, before the account goes.
  ///
  /// The rules let only the two parties touch a request, so a meeting left
  /// behind here can never be removed by anyone — and it would keep its slot
  /// blocked against a company that is still exhibiting, for a person who no
  /// longer exists. Failures are swallowed: losing the account is the point of
  /// the operation, and a stuck request must not stand in the way of it.
  Future<void> _cancelMeetings() async {
    final repository = _ref.read(meetingRepositoryProvider);
    for (final meeting in _ref.read(meetingsProvider)) {
      try {
        await repository.respond(meeting, MeetingStatus.declined);
      } catch (error) {
        debugPrint('Toplantı iptal edilemedi: $error');
      }
    }
  }
}

final accountDeletionProvider = Provider<AccountDeletion>(AccountDeletion.new);

/// Confirmation for an irreversible, outward-facing delete.
///
/// Spelled out rather than a bare "Emin misin?": the user has to be able to
/// see what disappears before they agree to it.
Future<bool?> showDeleteAccountDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppPalette.inkOverlay,
      title: Text(title, style: AppTypography.titleMedium),
      content: Text(message, style: AppTypography.bodySmall),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.textSecondary,
          ),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppPalette.danger),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
}

/// Outlined in the danger colour, never filled: a destructive action should be
/// reachable without being the thing the eye lands on first.
class DangerAction extends StatelessWidget {
  const DangerAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
            border: Border.all(
              color: AppPalette.danger.withValues(alpha: 0.42),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppPalette.danger),
              const SizedBox(width: AppSpace.sm),
              Text(
                label,
                style: AppTypography.label.copyWith(color: AppPalette.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
