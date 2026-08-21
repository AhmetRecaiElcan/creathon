import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

bool _ready = false;

/// Whether [bootFirebase] managed to bring the SDK up this run.
///
/// Every repository checks this before touching Auth or Firestore. Widget tests
/// never call [bootFirebase] and no plugin is registered there, so the flag
/// stays false and the app falls back to its offline repositories instead of
/// crashing on a missing platform channel.
bool get firebaseReady => _ready;

/// Brings Firebase up, tolerating failure.
///
/// A missing `google-services.json`, a platform with no app registered yet, or
/// an unreachable network must not stop the app from starting: the visitor
/// experience still renders, only signed-in features report that the backend is
/// unavailable.
Future<void> bootFirebase() async {
  if (_ready) return;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: options);
    _ready = true;
  } catch (error, stack) {
    _ready = false;
    debugPrint('Firebase başlatılamadı: $error');
    debugPrintStack(stackTrace: stack);
  }
}

/// Test seam: lets a test declare the backend present or absent.
@visibleForTesting
void debugSetFirebaseReady(bool value) => _ready = value;
