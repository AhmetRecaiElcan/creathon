import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_boot.dart';
import 'features/profile/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Awaited before the first frame so no screen can query Auth or Firestore
  // while the SDK is still coming up. A failure here is survivable — the app
  // falls back to its offline repositories.
  await bootFirebase();

  // The aurora runs edge to edge, so the system bars must be transparent and
  // draw over it rather than cutting it off with an opaque strip.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // The container is built here rather than by ProviderScope so the session
  // can be restored into it before the router evaluates its first redirect —
  // otherwise a returning visitor sees the welcome screen flash past.
  final container = ProviderContainer();
  await restoreSession(container)
      // A slow network must not hold the splash screen hostage; whatever has
      // not arrived by now simply means starting from the welcome screen.
      .timeout(const Duration(seconds: 6), onTimeout: () {})
      .catchError((Object error) => debugPrint('Oturum atlandı: $error'));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TakeOffApp(),
    ),
  );
}
