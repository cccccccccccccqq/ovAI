import 'dart:js_interop';

@JS('prepareOvChapterEmulator')
external JSPromise<JSAny?> _prepareOvChapterEmulator(
  JSString host,
  JSString appName,
);

/// Connect the public JS Auth SDK before FlutterFire restores its cached user.
/// On web, initializeApp itself awaits Auth initialization, so connecting the
/// emulator only after that call is too late for a persisted local account.
Future<void> prepareChapterWebEmulator({
  required String host,
  String appName = 'ov-history-local',
}) async {
  await _prepareOvChapterEmulator(host.toJS, appName.toJS).toDart;
}
