import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public Firebase SDK settings for the registered ov-ai-5ae61 cloud apps.
/// Service credentials and App Check debug tokens are never stored here.
class DevFirebaseOptions {
  DevFirebaseOptions._();
  static const googleWebClientId =
      "765364993612-pri91hps3u92lghntnobpiog5a0ccr2m.apps.googleusercontent.com";

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Register this platform with Firebase first.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyC23su6oWv1BquNY48r0N_yY9alEsBrmtA",
    appId: "1:765364993612:web:f719ddc9380301a12bbee9",
    messagingSenderId: "765364993612",
    projectId: "ov-ai-5ae61",
    storageBucket: "ov-ai-5ae61.firebasestorage.app",
    authDomain: "ov-ai-5ae61.firebaseapp.com",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyAmENznH0qsYBEv0Qh7GQoE7eyRl9TLxCU",
    appId: "1:765364993612:android:7c51dd78f0b205622bbee9",
    messagingSenderId: "765364993612",
    projectId: "ov-ai-5ae61",
    storageBucket: "ov-ai-5ae61.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyCXbCD14W3IsulaDb9UfG6fZEsmQJP4t88",
    appId: "1:765364993612:ios:f8a6ce21c5f7cd982bbee9",
    messagingSenderId: "765364993612",
    projectId: "ov-ai-5ae61",
    storageBucket: "ov-ai-5ae61.firebasestorage.app",
    iosBundleId: "mn.ov.ovChronicles",
    iosClientId:
        "765364993612-buhd7rrhm3cmmm0p3v5g1jhs0r5nshd4.apps.googleusercontent.com",
  );
}
