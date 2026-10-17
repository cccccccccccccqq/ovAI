import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_gateway.dart';

export 'auth_gateway.dart';

/// Keeps Firebase session state separate from the local prototype's library.
class SocialAuthController extends ChangeNotifier {
  SocialAuthController(this._gateway);

  final AuthGateway _gateway;
  StreamSubscription<AppIdentity?>? _subscription;
  Future<void>? _initializing;
  AppIdentity? _identity;
  bool _busy = false;
  bool _initialized = false;
  bool _disposed = false;
  String? _errorMessage;

  AppIdentity? get identity => _identity;
  bool get busy => _busy;
  bool get initialized => _initialized;
  bool get isEmulator => _gateway.isEmulator;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _identity?.isRegistered ?? false;

  Future<void> initialize() {
    if (_disposed || _initialized) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    _busy = true;
    _errorMessage = null;
    _notify();
    try {
      await _gateway.initialize();
      if (_disposed) return;
      _identity = _gateway.currentIdentity;
      _subscription = _gateway.identityChanges.listen(
        (identity) {
          if (_disposed) return;
          _identity = identity;
          _notify();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_disposed) return;
          _errorMessage = _messageFor(error);
          _notify();
        },
      );
      _initialized = true;
    } catch (error) {
      if (!_disposed) _errorMessage = _messageFor(error);
    } finally {
      _initializing = null;
      _busy = false;
      _notify();
    }
  }

  Future<bool> signIn(SocialProvider provider) async {
    if (_disposed || _busy) return false;
    if (!_initialized) {
      await initialize();
      if (!_initialized || _disposed || _busy) return false;
    }
    _busy = true;
    _errorMessage = null;
    _notify();
    try {
      final identity = await _gateway.signIn(provider);
      if (!_disposed) {
        if (_gateway.currentIdentity?.uid != identity.uid) {
          throw const AuthFailure('account-changed');
        }
        _identity = identity;
        return true;
      }
      return false;
    } catch (error) {
      if (!_disposed) _errorMessage = _messageFor(error);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<bool> signOut() async {
    if (_disposed || _busy || !_initialized) return false;
    _busy = true;
    _errorMessage = null;
    _notify();
    try {
      await _gateway.signOut();
      if (!_disposed) {
        _identity = _gateway.currentIdentity;
        return _identity == null;
      }
      return false;
    } catch (error) {
      if (!_disposed) _errorMessage = _messageFor(error);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clearError() {
    if (_errorMessage == null || _disposed) return;
    _errorMessage = null;
    _notify();
  }

  static String? _messageFor(Object error) {
    if (error is! AuthFailure) {
      return 'Sign-in is unavailable. Please try again.';
    }
    if (error.isCancelled) return null;
    return switch (error.code) {
      'network-request-failed' || 'network_error' =>
        'Could not connect. Check your connection and try again.',
      'popup-blocked' =>
        'Allow sign-in popups in your browser, then try again.',
      'operation-not-allowed' || 'configuration-not-found' =>
        'This sign-in provider is not configured yet.',
      'native-google-not-configured' ||
      'clientConfigurationError' ||
      'providerConfigurationError' =>
        'Google sign-in needs the app OAuth configuration. Use local web sign-in until setup is complete.',
      'unauthorized-domain' =>
        'This app address is not authorized for sign-in yet.',
      'credential-already-in-use' ||
      'account-exists-with-different-credential' ||
      'email-already-in-use' =>
        'This account is already in use. Sign out before signing in with it.',
      'user-disabled' => 'This account is disabled. Contact support.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'unsupported-platform' || 'native-emulator-provider' =>
        'Use the web emulator to test sign-in locally on this device.',
      'account-changed' =>
        'The active account changed. Please try signing in again.',
      'not-initialized' => 'Sign-in is not ready yet. Please try again.',
      _ => 'Sign-in is unavailable. Please try again.',
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_gateway.dispose());
    super.dispose();
  }
}
