enum JourneyMapProvider { google, osm }

/// Maps credentials are selected for the current build. Restrict each platform's
/// key in Google Cloud; a browser or mobile key is included in the shipped app.
class JourneyMapConfig {
  JourneyMapConfig._({
    required this.requestedProvider,
    required this.googleMapsApiKey,
    required this.googleMapId,
  });

  factory JourneyMapConfig.fromValues({
    String provider = 'google',
    String googleMapsApiKey = '',
    String googleMapId = 'DEMO_MAP_ID',
  }) {
    final normalized = provider.trim().toLowerCase();
    final requestedProvider = switch (normalized) {
      'google' => JourneyMapProvider.google,
      'osm' => JourneyMapProvider.osm,
      _ => throw ArgumentError.value(
        provider,
        'MAP_PROVIDER',
        'Use google or osm.',
      ),
    };
    return JourneyMapConfig._(
      requestedProvider: requestedProvider,
      googleMapsApiKey: googleMapsApiKey.trim(),
      googleMapId: googleMapId.trim().isEmpty
          ? 'DEMO_MAP_ID'
          : googleMapId.trim(),
    );
  }

  static final environment = JourneyMapConfig.fromValues(
    provider: const String.fromEnvironment(
      'MAP_PROVIDER',
      defaultValue: 'google',
    ),
    googleMapsApiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
    googleMapId: const String.fromEnvironment(
      'GOOGLE_MAP_ID',
      defaultValue: 'DEMO_MAP_ID',
    ),
  );

  final JourneyMapProvider requestedProvider;
  final String googleMapsApiKey;
  final String googleMapId;

  /// A build without a Google key remains usable with the existing OSM map.
  JourneyMapProvider get provider =>
      requestedProvider == JourneyMapProvider.google &&
          googleMapsApiKey.isNotEmpty
      ? JourneyMapProvider.google
      : JourneyMapProvider.osm;

  bool get usesGoogle => provider == JourneyMapProvider.google;

  String get providerLabel => usesGoogle ? 'Google Maps' : 'OpenStreetMap';
}
