import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import '../core/firebase/firebase_options.dart';
import 'admin_home.dart';
import 'admin_session.dart';
import 'login_screen.dart';

/// The T3 panel's shell.
///
/// A separate entrypoint rather than a route inside the app: the phone build is
/// a role-based mobile shell with a bottom bar and a 3D hall, and none of that
/// belongs in a browser tab. What is shared is what should be — the domain
/// models, the Firebase setup and the Turkish failure wording — because the
/// panel and the phone disagreeing about what a role is called is the one bug
/// this feature cannot survive.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  static const _ink = Color(0xFF0B0F1A);
  static const _card = Color(0xFF141A2A);
  static const _accent = Color(0xFF3B9BFF);

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'Take Off — Yönetim',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: _ink,
        colorScheme: base.colorScheme.copyWith(
          primary: _accent,
          surface: _card,
        ),
        cardTheme: const CardThemeData(color: _card),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const _AdminGate(),
    );
  }
}

/// Decides which of the panel's three states the operator is in.
class _AdminGate extends ConsumerWidget {
  const _AdminGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing below can work without the SDK, and the likeliest reason it is
    // missing is that the web app has never been registered — a setup step no
    // amount of retrying fixes, so say so plainly instead of spinning.
    if (!firebaseReady) return const _SetupNeeded();

    final session = ref.watch(adminSessionProvider);
    return switch (session) {
      AsyncData(value: final data) => switch (data.status) {
        AdminStatus.admin => const AdminHome(),
        AdminStatus.notAdmin => _NotAdmin(email: data.email),
        AdminStatus.signedOut => const LoginScreen(),
      },
      AsyncError() => const LoginScreen(),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

/// Shown when the browser has no Firebase app to talk to.
class _SetupNeeded extends StatelessWidget {
  const _SetupNeeded();

  @override
  Widget build(BuildContext context) {
    final configured = DefaultFirebaseOptions.webConfigured;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.settings_outlined, size: 32),
                  const SizedBox(height: 16),
                  Text(
                    'Panel yapılandırılmamış',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    configured
                        ? 'Firebase başlatılamadı. İnternet bağlantısını ve '
                              'proje ayarlarını kontrol et.'
                        : 'Firebase konsolunda bir Web uygulaması kaydet, '
                              'sonra apiKey ve appId değerlerini '
                              'lib/core/firebase/firebase_options.dart '
                              'içindeki web bloğuna yaz.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Correct credentials, wrong account.
class _NotAdmin extends ConsumerWidget {
  const _NotAdmin({this.email});

  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 32),
                const SizedBox(height: 16),
                Text(
                  'Bu hesap yönetici değil',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${email ?? 'Bu hesap'} panele yetkili değil. '
                  'Yetki vermek için Firebase konsolunda admins '
                  'koleksiyonuna hesabın uid’si ile bir belge ekle.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => ref.read(adminAuthProvider).signOut(),
                  child: const Text('Çıkış yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
