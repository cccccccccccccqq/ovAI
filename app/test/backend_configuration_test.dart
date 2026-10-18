import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/backend/backend_configuration.dart';

void main() {
  test('cloud is the default and emulator requires an explicit backend', () {
    expect(BackendConfiguration.parse().isEmulator, isFalse);
    expect(BackendConfiguration.parse(authMode: 'live').isEmulator, isFalse);
    expect(BackendConfiguration.parse(authMode: 'cloud').isEmulator, isFalse);
    expect(
      BackendConfiguration.parse(
        backendMode: 'emulator',
        authMode: 'emulator',
      ).isEmulator,
      isTrue,
    );
    expect(
      BackendConfiguration.parse(backendMode: 'emulator').isEmulator,
      isTrue,
    );
  });

  test(
    'mixed Auth and data environments fail instead of silently splitting UIDs',
    () {
      for (final modes in [
        ('cloud', 'emulator'),
        ('emulator', 'live'),
        ('emulator', 'cloud'),
        ('production', ''),
        ('cloud', 'invalid'),
      ]) {
        expect(
          () => BackendConfiguration.parse(
            backendMode: modes.$1,
            authMode: modes.$2,
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test('cloud guests and anonymous accounts cannot access owner data', () {
    for (final uid in [null, '', 'anonymous-uid']) {
      final session = BackendSession(
        uid: uid,
        isAnonymous: true,
        isEmulator: false,
      );
      expect(session.canAccessPrivateData, isFalse);
      expect(() => session.requireOwner(currentUid: uid), throwsStateError);
    }
  });

  test('private operations stay bound to the main authenticated UID', () {
    const session = BackendSession(
      uid: 'google-uid',
      isAnonymous: false,
      isEmulator: false,
    );
    expect(session.requireOwner(currentUid: 'google-uid'), 'google-uid');
    expect(
      () => session.requireOwner(currentUid: 'other-uid'),
      throwsStateError,
    );
    expect(() => session.requireOwner(currentUid: null), throwsStateError);
  });

  test('anonymous owner access remains exclusive to explicit local mode', () {
    const session = BackendSession(
      uid: 'local-uid',
      isAnonymous: true,
      isEmulator: true,
    );
    expect(session.requireOwner(currentUid: 'local-uid'), 'local-uid');
    expect(
      () => session.requireOwner(currentUid: 'other-uid'),
      throwsStateError,
    );
  });
  test('App Check debug providers require debug builds, including web', () {
    for (final isWeb in [false, true]) {
      expect(
        () => AppCheckConfiguration.parse(
          isDebugBuild: false,
          debug: true,
          isWeb: isWeb,
          host: 'localhost',
        ),
        throwsStateError,
      );
    }
    expect(
      AppCheckConfiguration.parse(isDebugBuild: true, debug: true).debug,
      isTrue,
    );
    expect(
      AppCheckConfiguration.parse(
        isDebugBuild: true,
        debug: true,
        isWeb: true,
        host: 'localhost',
      ).webSiteKey,
      'local-debug-provider',
    );
    expect(
      () => AppCheckConfiguration.parse(
        isDebugBuild: true,
        debug: true,
        isWeb: true,
        host: 'ov-ai-5ae61.web.app',
      ),
      throwsStateError,
    );
  });

  test(
    'production web App Check requires a registered public provider key',
    () {
      expect(
        () => AppCheckConfiguration.parse(isDebugBuild: false, isWeb: true),
        throwsStateError,
      );
      expect(
        () => AppCheckConfiguration.parse(
          isDebugBuild: false,
          isWeb: true,
          webSiteKey: 'public-key',
          webProvider: 'untrusted',
        ),
        throwsStateError,
      );
      final production = AppCheckConfiguration.parse(
        isDebugBuild: false,
        isWeb: true,
        webSiteKey: 'public-key',
      );
      expect(production.debug, isFalse);
      expect(production.webProvider, 'recaptcha-enterprise');
      expect(production.webSiteKey, 'public-key');
    },
  );
}
