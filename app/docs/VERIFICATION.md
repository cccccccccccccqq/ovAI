# v0.1 verification — 2026-10-15

## Automated

- `flutter analyze`: No issues found.
- `flutter test`: 24 tests pass (14 prototype tests, 5 route motion tests and 5 persistent navigation tests).
- All 19 screens render at 390 × 844 without layout exceptions.
- Complete welcome → named profile → site → prepared genre → narrator → local preparation → saved Reader flow passes.
- Guest creation gate returns to exploration without a loop.
- Non-default genre/style/mood/seed survives voice and cover changes.
- Profile, library, bookmarks, reading/audio position, queue and settings survive state reload.
- Download commit/cancel, failure rollback, removal and controller disposal pass race tests.
- Navigation push/pop preserves the prior page, tab replacement keeps one root page, and rapid changes settle at the final destination.
- Story-path changes animate while query updates retain page state. System Reduce Motion skips route animation.
- The same bottom navigation and icon elements keep identical screen coordinates during page transitions. One yellow capsule slides horizontally between tabs; rapid taps and Reduce Motion are covered.
- `flutter build web --release --no-wasm-dry-run`: success.
- `flutter build ios --simulator --debug`: success.

## Browser review

- Welcome, local profile, illustrated discovery map, prepared story selection and narrator summary exercised.
- Actual narration loaded; duration and playback position advanced to completion. Widget tests use a native-audio stub and do not make this decoding assertion.
- Reader and story remain accessible after reload.
- Portable prepared-story route opens its expected template.
- PDF exported as a real `%PDF-1.5` file.
- PNG exported as a real 1440 × 1920 PNG; visually inspected for title, cover, subtitle and demo label.
- Bundled Kharkhorin pack writes 452 KB to browser IndexedDB, remains installed after reload and returns to 0 KB after removal.
- Screenshots under `docs/screenshots/` were captured from the actual running browser application.
- Smooth tab navigation and Settings → back were exercised in the rebuilt web preview. Routes use 220–320 ms eased slide/fade transitions, with a 240 ms reverse transition. Tab-page motion applies only to the shell's content; the navigation surface stays fixed and its capsule moves over 280 ms.

## Platform limits

- Native iOS app built, installed and launched on an iPhone 17 Pro simulator. Native visual automation was unavailable because macOS Computer Use permissions were not granted; UI visual checks used the browser.
- Android source/configuration is present. Android compilation has not been run because this host has no Android SDK.
- Physical camera, photo library permission denial, real GPS arrival and native share-sheet destinations require device review. Automated route checks do not invoke hardware permission prompts.
- No live AI, Firebase authentication, cloud sync, background geofencing, push or background audio was integrated. The prototype clearly identifies its local profiles and prepared content.
- Web preview requires the local server. Explicit pack storage is persistent, but this build does not install a PWA service worker or claim cold-start web availability without a connection.
