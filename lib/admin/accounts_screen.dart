import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_profile.dart';
import 'account_admin_repository.dart';

/// Registered accounts, and the way to remove one for good.
///
/// Deliberately the last section of the panel: it is the only place that
/// destroys data nobody can put back.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Hesap silme geri alınamaz',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bir hesabı sildiğinde profili, yayınladığı kart, tuttuğu '
                  'stant, iki taraftaki görüşmeleri ve değerlendirmeleri de '
                  'gider. Davet listesindeki satırı ise kalır — silinen kişi '
                  'istenirse yeniden kayıt olabilir.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'KAYITLI HESAPLAR',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        switch (accounts) {
          AsyncData(value: final rows) when rows.isEmpty => const _Message(
            'Henüz kayıt olmuş kimse yok.',
          ),
          AsyncData(value: final rows) => Column(
            children: [for (final account in rows) _AccountRow(account: account)],
          ),
          AsyncError(error: final error) => _Message('Okunamadı: $error'),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _AccountRow extends ConsumerStatefulWidget {
  const _AccountRow({required this.account});

  final UserProfile account;

  @override
  ConsumerState<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends ConsumerState<_AccountRow> {
  bool _busy = false;
  String? _error;

  UserProfile get _account => widget.account;

  Future<void> _confirmDelete(bool hasCard) async {
    final label = _account.fullName.isEmpty
        ? _account.email
        : '${_account.fullName} (${_account.email})';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı tamamen sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label silinecek.'),
            const SizedBox(height: 12),
            const Text('Birlikte gidenler:'),
            const SizedBox(height: 4),
            const Text('•  Authentication hesabı ve profil belgesi'),
            if (hasCard)
              const Text('•  Yayınlanmış kart ve tuttuğu stant')
            else
              const Text('•  (yayınlanmış kartı yok)'),
            const Text('•  İki taraftaki tüm görüşme kayıtları'),
            const Text('•  Bu görüşmelere verilmiş değerlendirmeler'),
            const SizedBox(height: 12),
            const Text('Bu işlem geri alınamaz.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kalıcı olarak sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final teardown = await ref
          .read(accountAdminRepositoryProvider)
          .delete(_account.uid!);
      if (!mounted) return;
      // The row itself disappears when the stream updates, so the outcome is
      // reported where it will still be read: a snackbar with the counts, so
      // the operator can see the teardown actually reached the meetings.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_account.email} — ${teardown.summary}')),
      );
    } on AccountFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _account.role;
    final uid = _account.uid;
    final hasCard =
        uid != null &&
        (ref.watch(cardHoldersProvider).value?.contains(uid) ?? false);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  role?.icon ?? Icons.person_outline,
                  color: role?.accent ?? Colors.white38,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _account.fullName.isEmpty
                            ? _account.email
                            : _account.fullName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        [
                          if (_account.fullName.isNotEmpty) _account.email,
                          if (_account.companyName.trim().isNotEmpty)
                            _account.companyName.trim(),
                        ].join('  ·  '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _Tag(
                  label: role?.label ?? 'rol yok',
                  color: role?.accent ?? Colors.white38,
                ),
                const SizedBox(width: 8),
                if (hasCard)
                  const _Tag(label: 'kart yayında', color: Color(0xFF3B9BFF)),
                if (hasCard) const SizedBox(width: 8),
                if (!_account.emailVerified)
                  const _Tag(label: 'doğrulanmamış', color: Colors.white38),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Hesabı tamamen sil',
                    onPressed: uid == null
                        ? null
                        : () => _confirmDelete(hasCard),
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
