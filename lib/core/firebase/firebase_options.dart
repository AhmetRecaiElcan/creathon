import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase project configuration, transcribed from `google-services.json`.
///
/// Android could read that file straight off the Gradle-generated resources,
/// but passing the options explicitly keeps initialisation identical on every
/// platform and makes the values greppable from Dart.
///
/// Only Android is wired up so far — the other platforms need their own app
/// registered in the Firebase console before they can be added here.
abstract final class DefaultFirebaseOptions {
  static const projectId = 'creathon-9488f';

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAjqFRrhY94-Oyqc8srUiwYFqvi2aeCOk0',
    appId: '1:17666883029:android:024bbff64fa4fabc48d15c',
    messagingSenderId: '17666883029',
    projectId: projectId,
    storageBucket: 'creathon-9488f.firebasestorage.app',
  );
}
