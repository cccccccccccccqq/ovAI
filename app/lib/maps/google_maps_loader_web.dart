import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const _scriptId = 'ov-google-maps-sdk';
const _callbackName = 'ovChroniclesGoogleMapsReady';
final _authFailures = StreamController<void>.broadcast();
Future<void>? _loading;
bool _authenticationFailed = false;

Stream<void> get googleMapsAuthFailures => _authFailures.stream;

bool _isMapsReady() {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  final maps = google?.getProperty<JSObject?>('maps'.toJS);
  return maps?.getProperty<JSFunction?>('Map'.toJS) != null;
}

/// Loads the official Maps JavaScript API once, before Flutter's web map view
/// is constructed. Credential and browser error payloads are never logged.
Future<void> ensureGoogleMapsLoaded(String apiKey) {
  if (_authenticationFailed) {
    return Future<void>.error(StateError('Google Maps is unavailable.'));
  }
  if (_isMapsReady()) return Future<void>.value();
  return _loading ??= _load(apiKey);
}

Future<void> _load(String apiKey) {
  final completer = Completer<void>();
  late final Timer timeout;

  void fail() {
    if (!completer.isCompleted) {
      timeout.cancel();
      completer.completeError(
        StateError('Google Maps is unavailable. Try OpenStreetMap.'),
      );
    }
  }

  timeout = Timer(const Duration(seconds: 20), fail);
  globalContext.setProperty(
    _callbackName.toJS,
    (() {
      if (!completer.isCompleted) {
        timeout.cancel();
        if (_isMapsReady()) {
          completer.complete();
        } else {
          fail();
        }
      }
    }).toJS,
  );
  // Google calls this global callback for key/API/billing/referrer failures,
  // including failures reported after the script's ready callback.
  globalContext.setProperty(
    'gm_authFailure'.toJS,
    (() {
      _authenticationFailed = true;
      fail();
      _authFailures.add(null);
    }).toJS,
  );

  final script = web.HTMLScriptElement()
    ..id = _scriptId
    ..async = true
    ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
      'key': apiKey,
      'loading': 'async',
      'callback': _callbackName,
      'libraries': 'marker',
      'v': 'quarterly',
    }).toString();
  script.addEventListener('error', ((web.Event _) => fail()).toJS);
  // This widget owns its script; do not leave duplicate SDK scripts on retry.
  web.document.getElementById(_scriptId)?.remove();
  web.document.head!.appendChild(script);
  return completer.future;
}
