import 'dart:js_interop';

@JS('FIREBASE_APPCHECK_DEBUG_TOKEN')
external set _debugToken(JSBoolean value);

/// The SDK generates the token locally. No debug secret is bundled by the app.
/// Called only after debug-build and localhost checks in AppCheckConfiguration.
void enableWebAppCheckDebug() => _debugToken = true.toJS;
