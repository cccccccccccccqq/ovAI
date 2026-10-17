import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public SDK configuration downloaded for the registered development apps.
///
/// Importing this file does not initialize Firebase or switch the prototype
/// to cloud data. Pass [currentPlatform] explicitly when initializing live mode.
/// The configured Storage bucket is not provisioned yet; Blaze setup is required
/// before provisioning it and uploading media. Its name alone is not ready media.
class DevFirebaseOptions {
  DevFirebaseOptions._();

  /// Public OAuth web client created when Google sign-in was enabled.
  static const googleWebClientId =
      '146324418677-46lvrnt931s8vvfdhn0nr8ir9m91it1h.apps.googleusercontent.com';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'DevFirebaseOptions supports Web, Android, and iOS only. '
        'Register this platform before connecting it to Firebase.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAxxYmoeSNexV8U3zNPVL8k3tCk-ZkCXgM',
    appId: '1:146324418677:web:c41dbceb31c607c726883c',
    messagingSenderId: '146324418677',
    projectId: 'ov-chronicles-dev-20261016',
    authDomain: 'ov-chronicles-dev-20261016.firebaseapp.com',
    storageBucket: 'ov-chronicles-dev-20261016.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAvq0G0a60n6Uk1sE0_XF82jOSBRdb0cLQ',
    appId: '1:146324418677:android:88233851f333685326883c',
    messagingSenderId: '146324418677',
    projectId: 'ov-chronicles-dev-20261016',
    storageBucket: 'ov-chronicles-dev-20261016.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBhuZvvYHSDIUL4K2szGNhnNOT9PiSUbUI',
    appId: '1:146324418677:ios:fc032e81d896422526883c',
    messagingSenderId: '146324418677',
    projectId: 'ov-chronicles-dev-20261016',
    storageBucket: 'ov-chronicles-dev-20261016.firebasestorage.app',
    iosBundleId: 'mn.ov.ovChronicles',
    iosClientId: '146324418677-90pcdvfro47atm56p67kbn40ipmq88fi.apps.googleusercontent.com',
  );
}
