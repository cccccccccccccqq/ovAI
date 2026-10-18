# Firebase client foundation

> Current cloud target: **ov-ai-5ae61**. See [migration status](../../CLOUD_MIGRATION_STATUS.mn.md) and [cloud connection setup](CLOUD_CONNECTION.md). Explicit local runs require both `BACKEND_MODE=emulator` and `AUTH_MODE=emulator`.


The content/backend client lives in `lib/backend/`. It uses the real FlutterFire SDKs for Auth,
Firestore, callable Cloud Functions, and Storage. Importing it does not connect,
create an account, or change the prototype's local profile and library. The main
app now initializes a separate Auth-only social connection in `lib/auth/`.
Google is configured; Apple awaits developer/provider setup. See
[social auth setup](SOCIAL_AUTH_SETUP.md). Auth-only sign-in does not depend on
paid Cloud Functions/Storage.

## Local emulator

Start and seed the backend emulators using the repository's backend instructions.
After `WidgetsFlutterBinding.ensureInitialized()`, initialize once and retain the
returned instance:

```dart
final backend = await FirebaseBackend.initializeEmulators();
await backend.signInAnonymously(); // Explicit user/development action.
await backend.ensureProfile(EnsureProfileRequest(displayName: 'Traveller'));

final result = await backend.createPreparedChronicle(
  CreatePreparedChronicleRequest(
    requestId: 'saved-attempt-20261016-1',
    templateId: 'silver-tree', // Use an actual seeded template ID.
    voiceId: 'samantha',
  ),
);
```

Default project: `demo-ov-chronicles`. Functions region: `asia-northeast1`.
Ports: Auth `9099`, Firestore `18080`, Functions `5001`, Storage `9199`.
No cloud credentials are used. Emulator Firestore disk persistence is disabled.

### Runnable Flutter SDK check

With the emulators started and seeded, run this separate developer entry:

```sh
cd app
flutter run -d chrome -t lib/main_firebase_check.dart
```

Press **Run backend check**. It uses the actual FlutterFire SDKs to sign in,
parse the published catalog and private profile/story, retry one create request,
download M4A bytes from Storage, save library progress, delete the story, and
verify that retrying does not restore it. It signs out when finished. This entry
does not change the 19-screen prototype or import its device-local library.
Run again with a fresh anonymous account to repeat the check. Use
`--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2` for an Android emulator.

Use default host `127.0.0.1` on web/iOS simulator. On an Android emulator pass
`host: '10.0.2.2'`. A physical device needs the development computer's LAN IP,
emulators bound to an appropriate interface, and development-only cleartext
network settings. Do not enable those transport exceptions for production.

Reuse the same `requestId` when retrying one create operation; generate and save
a fresh ID for each new create intent. A replay can return `status: deleted` and
must not resurrect a removed story. Inputs are validated locally and again by
the server. Callable exceptions propagate to the UI for explicit error/retry
handling; permission and validation errors should not be retried indefinitely.

`watchSites()` and `watchPublishedTemplates()` read published catalog content.
`watchProfile()`, `watchLibrary()`, and `watchChronicle(id)` require sign-in first.
Create those subscriptions inside the signed-in user's scope; cancel them and
clear the private view whenever `authStateChanges()` emits a different user.
Private stream parsing checks that the original user is still signed in.

## Real project

Development project `ov-chronicles-dev-20261016` now has registered iOS, Android,
and web applications. Downloaded public configuration is in
`lib/backend/firebase_options_dev.dart`. Firestore rules/indexes and anonymous
Auth are deployed. The owner chose local emulators for now: live Functions,
Storage bucket, App Check providers, and cloud content are not deployed.
Pass the relevant options explicitly after completing those cloud steps:

```dart
final backend = await FirebaseBackend.initializeLive(
  options: DevFirebaseOptions.currentPlatform,
  configureAppCheck: (app) => FirebaseAppCheck.instanceFor(app: app).activate(
    providerWeb: ReCaptchaV3Provider(registeredWebSiteKey),
    providerAndroid: const AndroidPlayIntegrityProvider(),
    providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
  ),
);
```

The current FlutterFire packages use Firebase Apple SDK `12.19.0` and require
iOS `15.0` or later. The Podfile and Runner build configurations use that minimum;
keep `ios/Podfile.lock` so native dependencies resolve reproducibly.

Import `package:firebase_app_check/firebase_app_check.dart` for this setup. Register
the corresponding App Check providers in the new Firebase project. The backend
requires App Check for live callable functions. The initialization callback is
mandatory and finishes before the client is returned; no debug token is embedded.
Emulator mode never activates network attestation.

There is no fallback live project or automatic anonymous sign-in. Anonymous Auth
must be enabled if it is chosen for the guest flow. A production provider,
credential linking, App Check provider registration, account deletion, and the UI/auth state boundary
still need implementation before a public release.

## Story data and audio

`BackendChronicle` parses the immutable server snapshot (text segments,
citations, content version, voice, and Storage object path). Personal bookmark,
reading progress, and audio position belong in `BackendLibraryItem`. Firestore
timestamps are converted to UTC `DateTime`. The client never writes either
document directly; it calls `createPreparedChronicle`, `patchLibraryItem`, or
`deleteChronicle`.

`storageAudioReference(chronicle)` returns a Storage SDK `Reference` after owner,
status, and path checks. Use authenticated `getData(maxBytes)` or native
`writeToFile` to fetch/cache audio before playback. Do not store permanent
`getDownloadURL` bearer tokens for private stories. The authenticated audio
cache adapter and connection to `just_audio` remain separate work. Public
prepared catalog audio is reusable demo media, not generated TTS.

## Prototype migration boundary

The main app's `OvSessionApp` replaces navigation, reader and player state on
Firebase account changes. `AppState.loadForAccount` uses separate UID/environment
preference keys. The old guest/demo library remains separate and is not silently
imported into an account. Story records still store a local template ID rather
than complete text snapshots; connecting them to Firestore requires versioned
content migration and an explicit import/ownership flow. The new backend copies
prepared content; live AI/TTS generation is not implemented here.

Contract tests (`flutter test test/firebase_backend_contract_test.dart`) exercise
pure parsing and validation without invoking live Firebase or emulators.
