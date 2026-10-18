import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'backend_configuration.dart';
import 'app_check_web.dart';
import 'firebase_options_dev.dart';

/// Auth, catalog and owner data deliberately share one registered Firebase app.
/// Initializing this connection never creates an anonymous cloud account.
class CloudFirebase {
  CloudFirebase._();
  static Future<FirebaseApp>? _initializing;
  static final Map<String, Future<void>> _appCheck = {};

  static Future<FirebaseApp> initialize() async {
    try {
      return await (_initializing ??= _initialize());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  static Future<FirebaseApp> _initialize() async {
    final options = DevFirebaseOptions.currentPlatform;
    if (options.projectId != BackendConfiguration.cloudProjectId) {
      throw StateError('The cloud Firebase app must use ov-ai-5ae61.');
    }
    // The native Firestore plugin requires a default Core app even when its
    // actual reads use an explicitly named Firebase app.
    if (!kIsWeb && !Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
      await Firebase.initializeApp(options: options);
    }
    final matches = Firebase.apps.where(
      (app) => app.name == BackendConfiguration.cloudAppName,
    );
    final app = matches.isEmpty
        ? await Firebase.initializeApp(
            name: BackendConfiguration.cloudAppName,
            options: options,
          )
        : matches.single;
    if (app.options.projectId != options.projectId ||
        app.options.appId != options.appId) {
      throw StateError('Restart the app after changing Firebase projects.');
    }
    // Public browsing and sign-in can work while web attestation is being set
    // up. Protected callable requests still require successful App Check below.
    if (!kIsWeb ||
        const bool.fromEnvironment('APP_CHECK_DEBUG') ||
        const String.fromEnvironment('APP_CHECK_WEB_SITE_KEY').isNotEmpty) {
      await configureAppCheck(app);
    }
    return app;
  }

  static Future<void> configureAppCheck(FirebaseApp app) async {
    try {
      await (_appCheck[app.name] ??= _activateAppCheck(app));
    } catch (_) {
      _appCheck.remove(app.name);
      rethrow;
    }
  }

  static Future<void> _activateAppCheck(FirebaseApp app) async {
    final configuration = AppCheckConfiguration.parse(
      isDebugBuild: kDebugMode,
      debug: const bool.fromEnvironment('APP_CHECK_DEBUG'),
      isWeb: kIsWeb,
      host: kIsWeb ? Uri.base.host : '',
      webSiteKey: const String.fromEnvironment('APP_CHECK_WEB_SITE_KEY'),
      webProvider: const String.fromEnvironment(
        'APP_CHECK_WEB_PROVIDER',
        defaultValue: 'recaptcha-enterprise',
      ),
    );
    final check = FirebaseAppCheck.instanceFor(app: app);
    if (kIsWeb) {
      if (configuration.debug) enableWebAppCheckDebug();
      await check.activate(
        providerWeb: configuration.webProvider == 'recaptcha-enterprise'
            ? ReCaptchaEnterpriseProvider(configuration.webSiteKey)
            : ReCaptchaV3Provider(configuration.webSiteKey),
      );
    } else {
      await check.activate(
        providerAndroid: configuration.debug
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: configuration.debug
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
    await check.setTokenAutoRefreshEnabled(true);
  }

  /// A web build without a site key skips attestation; the callables then rely
  /// on Firebase Authentication alone until ENFORCE_APP_CHECK is turned on.
  /// Otherwise a missing or unregistered provider fails before a mutation.
  static Future<void> requireAppCheck(FirebaseApp app) async {
    if (kIsWeb &&
        !const bool.fromEnvironment('APP_CHECK_DEBUG') &&
        const String.fromEnvironment('APP_CHECK_WEB_SITE_KEY').isEmpty) {
      return;
    }
    await configureAppCheck(app);
    final token = await FirebaseAppCheck.instanceFor(app: app).getToken();
    if (token == null || token.isEmpty) {
      throw StateError('App verification is unavailable. Please try again.');
    }
  }
}
