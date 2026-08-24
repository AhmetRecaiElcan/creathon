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
    if (kIsWeb) return webConfigured ? web : null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  /// Whether the console values below have been filled in yet.
  ///
  /// Checked rather than assumed so the admin panel can put a setup screen in
  /// front of the operator instead of a stack trace: an unregistered web app
  /// fails inside `initializeApp` with a message that means nothing to whoever
  /// is trying to open the panel.
  static bool get webConfigured => web.appId.isNotEmpty;

  /// The admin panel's app. Android reads its values from
  /// `google-services.json`; a web app has no such file, so these are copied by
  /// hand from Firebase console → Project settings → Your apps → Web app.
  ///
  /// `authDomain` is the one Android does not need and the panel cannot work
  /// without — it is the origin the sign-in handshake runs against.
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyD9nrQDuR39GHv_9NnKupzzYZl62iEnhjE',
    appId: '1:17666883029:web:1f8a38aae86e56af48d15c',
    messagingSenderId: '17666883029',
    projectId: projectId,
    authDomain: '$projectId.firebaseapp.com',
    storageBucket: 'creathon-9488f.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAjqFRrhY94-Oyqc8srUiwYFqvi2aeCOk0',
    appId: '1:17666883029:android:024bbff64fa4fabc48d15c',
    messagingSenderId: '17666883029',
    projectId: projectId,
    storageBucket: 'creathon-9488f.firebasestorage.app',
  );
}
