# Cloud connection

The main application defaults to `BACKEND_MODE=cloud`, targeting
`ov-ai-5ae61`. Social sign-in and the published catalog use the same registered
Firebase app (`ov-social-live`). Creating a chronicle, loading its private library,
and saving progress use the main Google/Apple Firebase UID. Cloud startup never
creates an anonymous user. Guests may browse published catalog documents. In cloud mode all new prepared
chronicles, including Kharkhorin and Onon, use server snapshots and the same
private library. Published catalog records override bundled records by ID without
duplicating places. Bundled content and audio stay available in offline mode;
a failed connection never creates a local substitute for a cloud save.

A backend, rules, imported catalog/media and registered App Check providers must
be provisioned before this can be called a working deployment. Client SDK options
alone do not deploy services or upload data.

Cloud caches include the project ID and account UID. Existing emulator and older
project caches remain on the device and are not imported as cloud-owned records.
There is no fallback from cloud to a local emulator when a cloud request fails.

## Run

Cloud iOS simulator, after registering the SDK-generated App Check debug token:

```sh
flutter run -d <simulator-id> --dart-define=BACKEND_MODE=cloud --dart-define=APP_CHECK_DEBUG=true --dart-define-from-file=.maps-ios.local.json
```

`APP_CHECK_DEBUG` is accepted only for debug builds. Physical release builds use
App Attest with DeviceCheck fallback on Apple platforms, and Play Integrity on
Android. The corresponding provider must be registered in Firebase App Check.

A localhost-only web debug run can explicitly pass `--dart-define=APP_CHECK_DEBUG=true`
in a Flutter debug build. The SDK generates its own token; register it in the
Firebase Console and keep it private. This mode rejects non-loopback URLs and
release builds, and no debug secret is embedded in source.

Production web uses a public site key registered for the Firebase web app and allowed
production hostnames. Pass `--dart-define=APP_CHECK_WEB_SITE_KEY=<public-site-key>` and,
optionally, `--dart-define=APP_CHECK_WEB_PROVIDER=recaptcha-enterprise` (the default)
or `recaptcha-v3`. No reCAPTCHA secret belongs in client code. Missing or invalid
attestation blocks protected callables; server enforcement must remain enabled.

Explicit local development:

```sh
flutter run --dart-define=BACKEND_MODE=emulator --dart-define=AUTH_MODE=emulator --dart-define-from-file=.maps-web.local.json
```

`AUTH_MODE` is optional. When present, `live`/`cloud` must pair with a cloud
backend and `emulator` with an emulator backend. A mismatch fails at startup.
Local Auth, Firestore, Functions and Storage still target the isolated
`demo-ov-chronicles` project and explicitly configured emulator hosts.

Provider setup reference: https://firebase.google.com/docs/app-check/flutter/default-providers
and https://firebase.google.com/docs/app-check/web/recaptcha-enterprise-provider.
