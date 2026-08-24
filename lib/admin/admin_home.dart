import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accounts_screen.dart';
import 'admin_session.dart';
import 'events_screen.dart';
import 'invites_screen.dart';

/// The panel's chrome: which section is open, who is signed in, and the way out.
///
/// Both sections are built at once inside an [IndexedStack] rather than swapped,
/// so switching tabs does not restart their Firestore streams or throw away a
/// half-typed form — the organiser adding six events and then checking one
/// address should not come back to an empty form.
class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _index = 0;

  /// Order is meaningful: the two sections that publish come first, and the one
  /// that destroys sits last, where a misclick is least likely to land.
  static const _sections = [
    (label: 'Kayıt Tanımlamaları', icon: Icons.mail_outline),
    (label: 'Etkinlikler', icon: Icons.event_outlined),
    (label: 'Hesaplar', icon: Icons.people_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(adminSessionProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Off Yönetim'),
        actions: [
          if (session?.email != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  session!.email!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: () => ref.read(adminAuthProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final section in _sections)
                NavigationRailDestination(
                  icon: Icon(section.icon),
                  label: Text(section.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: IndexedStack(
                  index: _index,
                  children: const [
                    InvitesScreen(),
                    EventsAdminScreen(),
                    AccountsScreen(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
