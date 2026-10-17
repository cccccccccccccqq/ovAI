import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/auth/social_auth_controller.dart';

AppIdentity _person(String uid, {String provider = 'google.com'}) =>
    AppIdentity(
      uid: uid,
      displayName: 'A Traveler',
      email: '$uid@example.test',
      providers: {provider},
    );

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.isEmulator = true, AppIdentity? restored})
    : _current = restored;

  @override
  final bool isEmulator;
  AppIdentity? _current;
  final _changes = StreamController<AppIdentity?>.broadcast(sync: true);
  Future<void> Function()? onInitialize;
  Future<AppIdentity> Function(SocialProvider)? onSignIn;
  Future<void> Function()? onSignOut;
  int initializationCalls = 0;
  int signInCalls = 0;
  bool disposed = false;
  bool commitSignInResult = true;

  @override
  AppIdentity? get currentIdentity => _current;
  @override
  Stream<AppIdentity?> get identityChanges => _changes.stream;

  @override
  Future<void> initialize() async {
    initializationCalls++;
    await onInitialize?.call();
  }

  void emit(AppIdentity? identity) {
    _current = identity;
    _changes.add(identity);
  }

  @override
  Future<AppIdentity> signIn(SocialProvider provider) async {
    signInCalls++;
    final person =
        await (onSignIn?.call(provider) ??
            Future.value(_person('signed-in', provider: provider.providerId)));
    if (commitSignInResult) emit(person);
    return person;
  }

  @override
  Future<void> signOut() async {
    await onSignOut?.call();
    emit(null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _changes.close();
  }
}

void main() {
  test('restores the persisted SDK identity without a new sign-in', () async {
    final gateway = FakeAuthGateway(restored: _person('persisted'));
    final controller = SocialAuthController(gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.initialized, isTrue);
    expect(controller.busy, isFalse);
    expect(controller.identity?.uid, 'persisted');
    expect(controller.isSignedIn, isTrue);
    expect(gateway.signInCalls, 0);
    expect(controller.isEmulator, isTrue);
  });

  test('startup calls share initialization and expose loading', () async {
    final ready = Completer<void>();
    final gateway = FakeAuthGateway()..onInitialize = () => ready.future;
    final controller = SocialAuthController(gateway);
    addTearDown(controller.dispose);
    final first = controller.initialize();
    final second = controller.initialize();
    expect(controller.busy, isTrue);
    expect(gateway.initializationCalls, 1);
    ready.complete();
    await Future.wait([first, second]);
    expect(controller.initialized, isTrue);
    expect(controller.busy, isFalse);
  });

  test(
    'initialization failure leaves guest usable and supports retry',
    () async {
      final gateway = FakeAuthGateway()
        ..onInitialize = () async {
          throw const AuthFailure('network-request-failed');
        };
      final controller = SocialAuthController(gateway);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.identity, isNull);
      expect(controller.initialized, isFalse);
      expect(controller.busy, isFalse);
      expect(controller.errorMessage, contains('connection'));
      gateway.onInitialize = null;
      await controller.initialize();
      expect(controller.initialized, isTrue);
      expect(controller.errorMessage, isNull);
      expect(gateway.initializationCalls, 2);
    },
  );

  test('sign-in remains busy and ignores duplicate button presses', () async {
    final signedIn = Completer<AppIdentity>();
    final gateway = FakeAuthGateway()..onSignIn = (_) => signedIn.future;
    final controller = SocialAuthController(gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    final first = controller.signIn(SocialProvider.google);
    await controller.signIn(SocialProvider.apple);
    expect(controller.busy, isTrue);
    expect(gateway.signInCalls, 1);
    signedIn.complete(_person('google-user'));
    await first;
    expect(controller.identity?.uid, 'google-user');
    expect(controller.busy, isFalse);
  });

  test(
    'cancelled OAuth popup leaves the session and error unchanged',
    () async {
      final gateway = FakeAuthGateway()
        ..onSignIn = (_) async {
          throw const AuthFailure('popup-closed-by-user');
        };
      final controller = SocialAuthController(gateway);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(await controller.signIn(SocialProvider.google), isFalse);
      expect(controller.identity, isNull);
      expect(controller.errorMessage, isNull);
      expect(controller.busy, isFalse);
    },
  );

  test(
    'network failure is safe and the next provider attempt can succeed',
    () async {
      final gateway = FakeAuthGateway()
        ..onSignIn = (_) async {
          throw const AuthFailure('network-request-failed');
        };
      final controller = SocialAuthController(gateway);
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.signIn(SocialProvider.google);
      expect(controller.errorMessage, contains('connection'));
      gateway.onSignIn = null;
      await controller.signIn(SocialProvider.apple);
      expect(controller.errorMessage, isNull);
      expect(controller.identity?.providers, {'apple.com'});
    },
  );

  test('anonymous account upgrade preserves its UID', () async {
    final guest = AppIdentity(
      uid: 'anonymous-owner',
      providers: {},
      isAnonymous: true,
    );
    final gateway = FakeAuthGateway(restored: guest)
      ..onSignIn = (provider) async =>
          _person('anonymous-owner', provider: provider.providerId);
    final controller = SocialAuthController(gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.isSignedIn, isFalse);
    await controller.signIn(SocialProvider.apple);
    expect(controller.identity?.uid, 'anonymous-owner');
    expect(controller.isSignedIn, isTrue);
  });

  test(
    'link conflict does not silently switch or merge the anonymous user',
    () async {
      final guest = AppIdentity(uid: 'guest', providers: {}, isAnonymous: true);
      final gateway = FakeAuthGateway(restored: guest)
        ..onSignIn = (_) async {
          throw const AuthFailure('credential-already-in-use');
        };
      final controller = SocialAuthController(gateway);
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.signIn(SocialProvider.google);
      expect(controller.identity?.uid, 'guest');
      expect(controller.identity?.isAnonymous, isTrue);
      expect(controller.errorMessage, contains('already in use'));
    },
  );

  test(
    'SDK account switches update the identity and sign-out clears it',
    () async {
      final gateway = FakeAuthGateway(restored: _person('first'));
      final controller = SocialAuthController(gateway);
      addTearDown(controller.dispose);
      await controller.initialize();
      gateway.emit(_person('second', provider: 'apple.com'));
      expect(controller.identity?.uid, 'second');
      await controller.signOut();
      expect(controller.identity, isNull);
      expect(controller.isSignedIn, isFalse);
    },
  );

  test('sign-out failure keeps the active session and allows retry', () async {
    final gateway = FakeAuthGateway(restored: _person('active'))
      ..onSignOut = () async {
        throw const AuthFailure('network-request-failed');
      };
    final controller = SocialAuthController(gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(await controller.signOut(), isFalse);
    expect(controller.identity?.uid, 'active');
    expect(controller.errorMessage, isNotNull);
    gateway.onSignOut = null;
    expect(await controller.signOut(), isTrue);
    expect(controller.identity, isNull);
    expect(controller.errorMessage, isNull);
  });

  test('a stale sign-in result cannot overwrite a newer SDK account', () async {
    final signedIn = Completer<AppIdentity>();
    final gateway = FakeAuthGateway()
      ..commitSignInResult = false
      ..onSignIn = (_) => signedIn.future;
    final controller = SocialAuthController(gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    final pending = controller.signIn(SocialProvider.google);
    gateway.emit(_person('newer-session'));
    signedIn.complete(_person('stale-session'));
    expect(await pending, isFalse);
    expect(controller.identity?.uid, 'newer-session');
    expect(controller.errorMessage, contains('changed'));
  });

  test(
    'unexpected exceptions never expose provider responses or tokens',
    () async {
      final gateway = FakeAuthGateway()
        ..onSignIn = (_) async {
          throw StateError('Sensitive provider response access_token=secret');
        };
      final controller = SocialAuthController(gateway);
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.signIn(SocialProvider.google);
      expect(
        controller.errorMessage,
        'Sign-in is unavailable. Please try again.',
      );
      expect(controller.errorMessage, isNot(contains('secret')));
    },
  );

  test(
    'dispose during initialization does not notify or start a session',
    () async {
      final ready = Completer<void>();
      final gateway = FakeAuthGateway()..onInitialize = () => ready.future;
      final controller = SocialAuthController(gateway);
      final pending = controller.initialize();
      controller.dispose();
      ready.complete();
      await pending;
      expect(gateway.disposed, isTrue);
      expect(controller.initialized, isFalse);
    },
  );

  test('profile names are bounded and providers cannot be mutated', () {
    final identity = AppIdentity(
      uid: 'person',
      displayName: '  Өв\n  Traveler\t  ',
      providers: {'google.com'},
    );
    expect(identity.displayName, 'Өв Traveler');
    expect(() => identity.providers.add('apple.com'), throwsUnsupportedError);
    expect(AppIdentity.sanitizeDisplayName(' \n '), 'Traveler');
    expect(AppIdentity.sanitizeDisplayName('a' * 65).length, 60);
    expect(AppIdentity.sanitizeDisplayName('🌏' * 61).runes.length, 60);
  });
}
