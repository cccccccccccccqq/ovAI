import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../backend/firebase_options_dev.dart';
import '../backend/cloud_firebase.dart';
import 'auth_gateway.dart';

/// Uses the main Firebase app shared by cloud catalog and owner data.
/// Restoring a social session never creates an anonymous account on startup.
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway.live({this.googleServerClientId, this.googleIosClientId})
    : isEmulator = false,
      emulatorHost = '127.0.0.1',
      emulatorPort = 9099;

  FirebaseAuthGateway.emulator({
    this.emulatorHost = '127.0.0.1',
    this.emulatorPort = 9099,
  }) : isEmulator = true,
       googleServerClientId = null,
       googleIosClientId = null;

  @override
  final bool isEmulator;
  final String emulatorHost;
  final int emulatorPort;
  final String? googleServerClientId;
  final String? googleIosClientId;

  FirebaseAuth? _auth;
  Future<void>? _initializing;
  StreamSubscription<User?>? _subscription;
  final _changes = StreamController<AppIdentity?>.broadcast(sync: true);
  bool _disposed = false;
  Future<void>? _googleInitialization;

  @override
  AppIdentity? get currentIdentity => _identity(_auth?.currentUser);

  @override
  Stream<AppIdentity?> get identityChanges => _changes.stream;

  @override
  Future<void> initialize() {
    if (_disposed) throw const AuthFailure('not-initialized');
    if (_auth != null) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (isEmulator &&
          (emulatorHost.trim().isEmpty ||
              emulatorHost.contains('://') ||
              emulatorHost.contains('/') ||
              emulatorPort < 1 ||
              emulatorPort > 65535)) {
        throw const AuthFailure('invalid-emulator-address');
      }
      const appName = 'ov-social-emulator';
      final options = isEmulator
          ? FirebaseOptions(
              apiKey: 'ADemoProjectApiKey000000000000000000000',
              appId:
                  '1:1:${kIsWeb
                      ? 'web'
                      : defaultTargetPlatform == TargetPlatform.android
                      ? 'android'
                      : 'ios'}:1',
              messagingSenderId: '1',
              projectId: 'demo-ov-chronicles',
              authDomain: 'demo-ov-chronicles.firebaseapp.com',
              iosBundleId: 'mn.ov.ovChronicles',
            )
          : DevFirebaseOptions.currentPlatform;
      final existingApps = Firebase.apps.where((app) => app.name == appName);
      final app = !isEmulator
          ? await CloudFirebase.initialize()
          : existingApps.isEmpty
          ? await Firebase.initializeApp(name: appName, options: options)
          : existingApps.single;
      if (app.options.projectId != options.projectId) {
        throw const AuthFailure('configuration-not-found');
      }
      final auth = FirebaseAuth.instanceFor(app: app);
      if (isEmulator) {
        await auth.useAuthEmulator(
          emulatorHost,
          emulatorPort,
          automaticHostMapping: false,
        );
      }
      // On web, this waits for IndexedDB persistence to restore the SDK session.
      await auth.authStateChanges().first;
      if (_disposed) return;
      _auth = auth;
      _subscription = auth.userChanges().listen(
        (user) {
          if (!_disposed) _changes.add(_identity(user));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_disposed) _changes.addError(_safeFailure(error), stackTrace);
        },
      );
    } catch (error) {
      throw _safeFailure(error);
    } finally {
      _initializing = null;
    }
  }

  @override
  Future<AppIdentity> signIn(SocialProvider provider) async {
    final auth = _requireAuth();
    final startingUser = auth.currentUser;
    final startingUid = startingUser?.uid;
    try {
      final AuthProvider authProvider = switch (provider) {
        SocialProvider.google =>
          GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        // The native SDK passes Apple's first-login fullName into Firebase's
        // appleCredential; Firebase then persists it on the user profile.
        SocialProvider.apple =>
          AppleAuthProvider()
            ..addScope('email')
            ..addScope('name'),
      };
      late final UserCredential result;
      if (kIsWeb) {
        result = startingUser?.isAnonymous == true
            ? await startingUser!.linkWithPopup(authProvider)
            : await auth.signInWithPopup(authProvider);
      } else if (isEmulator) {
        // A native Google SDK would contact Google rather than the emulator.
        // Local fake OAuth accounts are entered in the web emulator popup.
        throw const AuthFailure('native-emulator-provider');
      } else if (provider == SocialProvider.google) {
        await _initializeGoogle();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const AuthFailure('invalid-credential');
        }
        if (auth.currentUser?.uid != startingUid) {
          throw const AuthFailure('account-changed');
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        result = startingUser?.isAnonymous == true
            ? await startingUser!.linkWithCredential(credential)
            : await auth.signInWithCredential(credential);
      } else {
        result = startingUser?.isAnonymous == true
            ? await startingUser!.linkWithProvider(authProvider)
            : await auth.signInWithProvider(authProvider);
      }
      final user = result.user;
      if (user == null || auth.currentUser?.uid != user.uid) {
        throw const AuthFailure('account-changed');
      }
      if (startingUser?.isAnonymous == true && user.uid != startingUid) {
        throw const AuthFailure('account-changed');
      }
      return _identity(user)!;
    } catch (error) {
      // In particular, credential-already-in-use is surfaced to the user. There
      // is no fallback sign-in that could switch users or lose anonymous data.
      throw _safeFailure(error);
    }
  }

  Future<void> _initializeGoogle() {
    const configuredIosClientId = String.fromEnvironment(
      'GOOGLE_IOS_CLIENT_ID',
    );
    const configuredWebClientId = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
    );
    final iosClientId =
        googleIosClientId ??
        (configuredIosClientId.isEmpty
            ? DevFirebaseOptions.ios.iosClientId
            : configuredIosClientId);
    final serverClientId =
        googleServerClientId ??
        (configuredWebClientId.isEmpty
            ? DevFirebaseOptions.googleWebClientId
            : configuredWebClientId);
    if ((defaultTargetPlatform == TargetPlatform.iOS &&
            iosClientId?.isNotEmpty != true) ||
        (defaultTargetPlatform == TargetPlatform.android &&
            serverClientId.isEmpty)) {
      throw const AuthFailure('native-google-not-configured');
    }
    return _googleInitialization ??= GoogleSignIn.instance
        .initialize(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? iosClientId
              : null,
          serverClientId: serverClientId,
        )
        .catchError((Object error) {
          _googleInitialization = null;
          throw _safeFailure(error);
        });
  }

  @override
  Future<void> signOut() async {
    try {
      await _requireAuth().signOut();
      // Firebase owns the session. Google account access is not revoked here;
      // revocation requires a separate, explicit user action.
    } catch (error) {
      throw _safeFailure(error);
    }
  }

  @override
  Future<void> deleteAccount() async {
    final auth = _requireAuth();
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthFailure('not-signed-in');
    }
    try {
      final providers = user.providerData.map((data) => data.providerId);
      final provider = providers.contains(SocialProvider.apple.providerId)
          ? SocialProvider.apple
          : SocialProvider.google;
      // A fresh sign-in proves the owner is present; the server rejects a
      // deletion whose sign-in is older than five minutes.
      final reauthenticated = await _reauthenticate(user, provider);
      if (auth.currentUser?.uid != user.uid ||
          reauthenticated.user?.uid != user.uid) {
        throw const AuthFailure('account-changed');
      }
      // Apple requires the app to revoke its tokens when the account is deleted.
      final appleCode = reauthenticated.additionalUserInfo?.authorizationCode;
      if (provider == SocialProvider.apple &&
          appleCode != null &&
          appleCode.isNotEmpty) {
        await auth.revokeTokenWithAuthorizationCode(appleCode);
      }
      await FirebaseFunctions.instanceFor(
        app: auth.app,
        region: 'asia-northeast1',
      ).httpsCallable('deleteAccount').call<dynamic>();
    } on FirebaseFunctionsException catch (error) {
      throw AuthFailure('delete-${error.code}');
    } catch (error) {
      throw _safeFailure(error);
    }
    // The server already removed the user; this only clears the local session.
    try {
      await auth.signOut();
    } catch (_) {}
  }

  Future<UserCredential> _reauthenticate(
    User user,
    SocialProvider provider,
  ) async {
    final AuthProvider authProvider = switch (provider) {
      SocialProvider.google =>
        GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
      SocialProvider.apple => AppleAuthProvider(),
    };
    if (kIsWeb) return user.reauthenticateWithPopup(authProvider);
    if (isEmulator) throw const AuthFailure('native-emulator-provider');
    if (provider == SocialProvider.apple) {
      return user.reauthenticateWithProvider(authProvider);
    }
    await _initializeGoogle();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure('invalid-credential');
    }
    return user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  FirebaseAuth _requireAuth() {
    if (_disposed || _auth == null) {
      throw const AuthFailure('not-initialized');
    }
    return _auth!;
  }

  static AppIdentity? _identity(User? user) {
    if (user == null) return null;
    String? displayName = user.displayName;
    if (displayName == null || displayName.trim().isEmpty) {
      for (final profile in user.providerData) {
        if (profile.displayName?.trim().isNotEmpty == true) {
          displayName = profile.displayName;
          break;
        }
      }
    }
    return AppIdentity(
      uid: user.uid,
      displayName: displayName,
      email: user.email,
      photoUrl: user.photoURL,
      providers: user.providerData.map((data) => data.providerId).toSet(),
      isAnonymous: user.isAnonymous,
      emailVerified: user.emailVerified,
    );
  }

  static AuthFailure _safeFailure(Object error) {
    return switch (error) {
      AuthFailure() => error,
      FirebaseAuthException() => AuthFailure(error.code),
      GoogleSignInException() => AuthFailure(error.code.name),
      PlatformException() => AuthFailure(error.code),
      _ => const AuthFailure('unknown'),
    };
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _changes.close();
    // Keep the named Firebase app and persisted session for the next launch.
  }
}
