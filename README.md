# Öv Flutter prototype

The functional 19-screen prototype is in [app](app/README.md).

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

The app now uses Firebase Authentication for Google sign-in, with Apple prepared but disabled until the developer/provider setup is complete. Stories and progress remain on this device, isolated by Firebase UID. Use AUTH_MODE=emulator for simulated social sign-in. A tested Firebase emulator backend is available separately; cloud story sync and live AI/TTS are not implemented.
