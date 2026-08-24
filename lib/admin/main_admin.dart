import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_boot.dart';
import 'admin_app.dart';

/// The T3 Vakfı admin panel — a second entrypoint into the same package.
///
/// Build it with:
///   flutter build web -t lib/admin/main_admin.dart -o build/admin
///
/// Nothing from `lib/main.dart` runs here: no session restore, no router, no
/// mobile shell. The panel signs in on its own and its whole surface is one
/// screen, so a `ProviderScope` and a `MaterialApp` are the entire bootstrap.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Not fatal, and deliberately so: the panel renders its own setup screen when
  // the web app has not been registered in the console yet.
  await bootFirebase();
  runApp(const ProviderScope(child: AdminApp()));
}
