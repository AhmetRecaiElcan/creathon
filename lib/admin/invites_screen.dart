import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/invite.dart';
import '../domain/user_role.dart';
import 'invite_admin_repository.dart';

/// Who may register, and as what.
///
/// A body, not a page: [AdminHome] owns the chrome so both of the panel's
/// sections sit under one header and one sign-out.
class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(invitesProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _AddInviteCard(),
        const SizedBox(height: 24),
        Text(
          'TANIMLI ADRESLER',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        switch (invites) {
          AsyncData(value: final rows) when rows.isEmpty => const _Empty(),
          AsyncData(value: final rows) => Column(
            children: [for (final invite in rows) _InviteRow(invite: invite)],
          ),
          AsyncError(error: final error) => _Message('Liste okunamadı: $error'),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

/// The form. Two required answers — the address and the audience — because
/// those are the only two things admission is made of.
class _AddInviteCard extends ConsumerStatefulWidget {
  const _AddInviteCard();

  @override
  ConsumerState<_AddInviteCard> createState() => _AddInviteCardState();
}

class _AddInviteCardState extends ConsumerState<_AddInviteCard> {
  final _email = TextEditingController();
  final _note = TextEditingController();
  UserRole? _role;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final role = _role;
    if (role == null) {
      setState(() => _error = 'Müşteri türünü seç.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      await ref
          .read(inviteAdminRepositoryProvider)
          .add(email: _email.text, role: role, note: _note.text);
      if (!mounted) return;
      final added = Invite.idFor(_email.text);
      setState(() {
        _busy = false;
        _done = '$added — ${role.label} olarak tanımlandı.';
        _email.clear();
        _note.clear();
      });
    } on InviteFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kaydedilemedi: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yeni adres tanımla',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tanımlanan adres, yalnızca seçilen müşteri türünden kayıt olabilir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta adresi',
              hintText: 'ad@kurum.com',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'MÜŞTERİ TÜRÜ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in UserRole.values)
                ChoiceChip(
                  label: Text(role.label),
                  avatar: Icon(role.icon, size: 18, color: role.accent),
                  selected: _role == role,
                  selectedColor: role.accent.withValues(alpha: 0.22),
                  onSelected: (_) => setState(() {
                    _role = role;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Not (opsiyonel)',
              hintText: 'jüri, TÜBİTAK standı, davetli konuşmacı…',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_done != null) ...[
            const SizedBox(height: 16),
            Text(_done!, style: const TextStyle(color: Color(0xFF2FD98A))),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Listeye ekle'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InviteRow extends ConsumerWidget {
  const _InviteRow({required this.invite});

  final Invite invite;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adresi listeden çıkar'),
        content: Text(
          '${invite.email} bundan sonra kayıt olamaz. '
          'Zaten kayıt olmuş bir hesap varsa çalışmaya devam eder — '
          'hesabı silmek ayrı bir iştir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(inviteAdminRepositoryProvider).remove(invite.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registered = ref
        .watch(registeredEmailsProvider)
        .value
        ?.contains(invite.id);
    final role = invite.role;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              role?.icon ?? Icons.help_outline,
              color: role?.accent ?? Colors.white38,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.email,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (invite.note.isNotEmpty)
                    Text(
                      invite.note,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            _Tag(
              label: role?.label ?? 'tür yok',
              color: role?.accent ?? Colors.white38,
            ),
            const SizedBox(width: 8),
            // Whether the guest actually arrived. "bekliyor" means the address
            // is admitted but nobody has finished signing up with it yet, which
            // is the state the organiser chases before the doors open.
            _Tag(
              label: registered == true ? 'kayıt oldu' : 'bekliyor',
              color: registered == true
                  ? const Color(0xFF2FD98A)
                  : Colors.white38,
            ),
            IconButton(
              tooltip: 'Listeden çıkar',
              onPressed: () => _confirmRemove(context, ref),
              icon: const Icon(Icons.delete_outline),
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

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) =>
      const _Message('Henüz tanımlı adres yok. Yukarıdan ekleyince buraya düşer.');
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}
