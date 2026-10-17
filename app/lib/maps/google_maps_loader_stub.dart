/// Native SDKs receive their key from platform configuration at app startup.
Future<void> ensureGoogleMapsLoaded(String apiKey) async {}

Stream<void> get googleMapsAuthFailures => const Stream<void>.empty();
