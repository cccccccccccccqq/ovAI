# Öv — stories of the steppe

> Current cloud target: **ov-ai-5ae61**. See [migration status](../CLOUD_MIGRATION_STATUS.mn.md) and [cloud connection setup](docs/CLOUD_CONNECTION.md). Explicit local runs require both `BACKEND_MODE=emulator` and `AUTH_MODE=emulator`.


A Flutter prototype of the supplied **Working app · iPhone** design. All 19 screens have working local interactions. Google sign-in now uses Firebase Auth; Apple sign-in is prepared but disabled pending developer/provider setup. Prepared stories, reading progress and recorded narration remain on device, with separate storage for each account.

The Firebase emulator backend and FlutterFire adapter are available separately.
See [backend setup](../BACKEND_FIREBASE.mn.md) and
[client guide](docs/FIREBASE_CLIENT.md). Run
`flutter run -d chrome -t lib/main_firebase_check.dart` after starting/seeding the
emulators to verify the real SDK flow. The default app uses live Auth; run
`flutter run -d chrome --dart-define=AUTH_MODE=emulator` for simulated Google/Apple
accounts. See [social sign-in setup](docs/SOCIAL_AUTH_SETUP.md). Story library
sync with Firestore remains separate work.

## Run

Use Flutter 3.41.7 / Dart 3.11.5 or compatible newer versions:

```sh
flutter pub get
flutter run -d chrome
```

For an iPhone simulator, start a simulator and run `flutter run`. Android project files are included; install the Android SDK and select a device before building Android. The OSM map needs no API key. For Google Maps, see [Maps setup](docs/MAPS_SETUP.md), run the local configuration helper, and supply the appropriate platform define file.

## What works

- Welcome and a named device-local profile, guest browsing, profile return flows.
- Four Orkhon Valley sites; searchable illustrated overview and optional live OpenStreetMap field view.
- Cover selection from bundled images, photo library or supported camera.
- Prepared genre/style/mood/seed presets that select different actual stories.
- Four real recorded narrators, previews, playback, seek, speed and saved position.
- Eleven story templates; a three-chapter branching Kharkhorin journey.
- Reading notes, bookmarks, separate Mine/Journeys/Explore views and local deletion.
- Persistent drafts, offline scenario queue/resume, theme and text-size settings.
- Demo pack installation/removal using actual files on mobile and IndexedDB on web.
- Share-card PNG and text PDF export, plus portable prepared-story links on web.
- Foreground location on explicit request; clearly labeled demo arrival for testing anywhere.

Story text is original prepared demo writing. Context notes link to background reading and are not represented as independently verified historical claims. Profiles are local and do not authenticate an online account. Cover photos are not sent to an AI model. Installed demo packs are copied from bundled assets; they do not contain downloaded map regions. Background audio, background geofencing, push, live AI and cloud sync are outside v0.1.

## Screens

Main, SignUp, Steppe, InscribePlace, InscribeTone, InscribeVoice, Writing, Reader, ReaderEnd, Scrolls, Orda, FieldMap, Geofence, Offline, Journey, ShareCard, Playback, Settings, Downloads.

Open `/#/welcome` for entry, `/#/steppe` for discovery, or `/#/demo/silver-tree` for a portable prepared-story link. Personal story URLs use local IDs and are not public share links.

## Verify / build

```sh
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run
flutter build ios --simulator --debug
```

State tests cover persistence, prepared selection propagation, branching and malformed data. Download tests cover commit/cancel races, failed writes and disposal. Widget tests exercise the complete creation flow, guest return behavior and all 19 screens at 390 × 844. Widget audio uses a platform stub; actual decoding requires browser/device review.

The `image` dependency is pinned to 4.5.4 because the image 4.11 / archive version combination selected alongside pdf 3.12 fails to compile on the current SDK. Keep `pubspec.lock` for reproducible builds. The browser build uses JavaScript; Wasm is not the target of this prototype.

## Assets

Images and the Ulzii SVG were copied from the supplied design export. Poppins and Inter are bundled from the official Google Fonts repository with their OFL licenses under `assets/fonts/`.

Narration is generated locally from the exact story text using macOS system voices Samantha, Daniel, Karen and Moira. It is not a Gemini voice or cloned speaker. To rebuild fonts and narration on macOS with `say` and FFmpeg installed:

```sh
python3 tool/prepare_assets.py
```

The text/voice manifest is `tool/narration_manifest.json`. Runtime playback uses only bundled M4A assets. Configured builds use official Google Maps SDKs; builds without a key use OpenStreetMap with attribution. No bulk tile downloads are implemented. Device location is requested explicitly, shown with its reported accuracy, and used conservatively for nearby arrival. Camera, photo library and foreground location prompts are configured for iOS/Android.

## Structure

`lib/core` contains models, prepared content, local state, audio and pack adapters. `lib/screens` implements the 19 screens. `lib/widgets` holds shared Geret widgets and the illustrated map. Repositories/services are separated from the view code so a future Firebase/AI adapter can replace the local content path.
