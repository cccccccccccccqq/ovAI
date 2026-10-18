# Öv Flutter prototype

The 19-screen Flutter application is in [app](app/README.md). Cloud migration targets **ov-ai-5ae61**. See the [current cloud migration status](CLOUD_MIGRATION_STATUS.mn.md) before running the default cloud build.

- [Run and feature guide](app/README.md)
- [Migration analysis](FLUTTER_MIGRATION_ANALYSIS.mn.md)
- [Prototype scope](PROTOTYPE_V01_PLAN.mn.md)
- [Production roadmap](PRODUCTION_ROADMAP.mn.md)
- [Firebase backend setup](BACKEND_FIREBASE.mn.md)
- [Google / Apple sign-in setup](app/docs/SOCIAL_AUTH_SETUP.md)
- [Google Maps setup](app/docs/MAPS_SETUP.md)

Start from this directory with:

```sh
cd app
flutter pub get
flutter run
```

The app defaults to `BACKEND_MODE=cloud`, using registered Google sign-in and App Check. Apple remains disabled until provider setup is complete. For local development pass both `--dart-define=BACKEND_MODE=emulator --dart-define=AUTH_MODE=emulator`.

The English Secret History collection now uses the same Steppe place card, Place/Tone/Voice screens, Reader, Player, Path and Scrolls library as Kharkhorin. Select **Onon River**: five chronological four-minute chapters, an alternate lyrical Chapter 1 and the same four English voices. Cloud mode loads published catalog records and saves all new prepared stories, parent paths, bookmarks and progress through the same Firebase account. Emulator mode remains explicitly selectable; previous local caches are retained separately. The cloud catalog/media upload and Functions deployment require the billing step described in the migration status. See [English series setup and verification](SECRET_HISTORY_ENGLISH.mn.md).
