/// Build-time selection keeps cloud and local accounts in separate backends.
class BackendConfiguration {
  const BackendConfiguration._(this.mode);
  final String mode;
  bool get isEmulator => mode == 'emulator';

  static const cloudProjectId = 'ov-ai-5ae61';
  static const cloudAppName = 'ov-social-live';
  static const emulatorProjectId = 'demo-ov-chronicles';

  factory BackendConfiguration.parse({
    String backendMode = 'cloud',
    String authMode = '',
  }) {
    if (backendMode != 'cloud' && backendMode != 'emulator') {
      throw ArgumentError('BACKEND_MODE must be cloud or emulator.');
    }
    if (authMode.isNotEmpty &&
        authMode != 'live' &&
        authMode != 'cloud' &&
        authMode != 'emulator') {
      throw ArgumentError('AUTH_MODE must be live, cloud, or emulator.');
    }
    if (authMode.isNotEmpty &&
        (authMode == 'emulator') != (backendMode == 'emulator')) {
      throw ArgumentError(
        'AUTH_MODE and BACKEND_MODE must use the same backend.',
      );
    }
    return BackendConfiguration._(backendMode);
  }

  static BackendConfiguration get current => BackendConfiguration.parse(
    backendMode: const String.fromEnvironment(
      'BACKEND_MODE',
      defaultValue: 'cloud',
    ),
    authMode: const String.fromEnvironment('AUTH_MODE'),
  );
}

/// Private reads and writes must belong to the main, current Firebase session.
/// Local anonymous accounts remain available only in explicitly selected tests.
class BackendSession {
  const BackendSession({
    required this.uid,
    required this.isAnonymous,
    required this.isEmulator,
  });
  final String? uid;
  final bool isAnonymous;
  final bool isEmulator;

  bool get canAccessPrivateData =>
      uid?.isNotEmpty == true && (isEmulator || !isAnonymous);

  String requireOwner({required String? currentUid}) {
    if (!canAccessPrivateData) {
      throw StateError('Sign in with Google or Apple to save this story.');
    }
    if (currentUid != uid) {
      throw StateError('The active account changed. Reopen your library.');
    }
    return uid!;
  }
}

/// Provider choices are validated before any App Check SDK activation.
class AppCheckConfiguration {
  const AppCheckConfiguration._({
    required this.debug,
    required this.webSiteKey,
    required this.webProvider,
  });
  final bool debug;
  final String webSiteKey;
  final String webProvider;

  factory AppCheckConfiguration.parse({
    required bool isDebugBuild,
    bool debug = false,
    bool isWeb = false,
    String host = '',
    String webSiteKey = '',
    String webProvider = 'recaptcha-enterprise',
  }) {
    if (debug && !isDebugBuild) {
      throw StateError('APP_CHECK_DEBUG is allowed only in a debug build.');
    }
    if (isWeb &&
        debug &&
        !const {'127.0.0.1', 'localhost', '::1', '[::1]'}.contains(host)) {
      throw StateError(
        'Web App Check debugging requires a localhost debug build.',
      );
    }
    if (isWeb && !debug && webSiteKey.isEmpty) {
      throw StateError(
        'Configure the public APP_CHECK_WEB_SITE_KEY before saving stories.',
      );
    }
    if (isWeb &&
        webProvider != 'recaptcha-enterprise' &&
        webProvider != 'recaptcha-v3') {
      throw StateError(
        'APP_CHECK_WEB_PROVIDER must be recaptcha-enterprise or recaptcha-v3.',
      );
    }
    return AppCheckConfiguration._(
      debug: debug,
      webSiteKey: debug && webSiteKey.isEmpty
          ? 'local-debug-provider'
          : webSiteKey,
      webProvider: webProvider,
    );
  }
}
