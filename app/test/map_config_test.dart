import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/maps/map_config.dart';

void main() {
  test('a Google build with a configured key selects Google Maps', () {
    final config = JourneyMapConfig.fromValues(
      googleMapsApiKey: 'example-platform-key',
    );
    expect(config.provider, JourneyMapProvider.google);
    expect(config.usesGoogle, isTrue);
    expect(config.providerLabel, 'Google Maps');
  });

  test('a build without a Google key remains usable with OpenStreetMap', () {
    final config = JourneyMapConfig.fromValues();
    expect(config.requestedProvider, JourneyMapProvider.google);
    expect(config.provider, JourneyMapProvider.osm);
    expect(config.usesGoogle, isFalse);
    expect(config.providerLabel, 'OpenStreetMap');
  });

  test(
    'an explicitly selected OSM build does not use a supplied Google key',
    () {
      final config = JourneyMapConfig.fromValues(
        provider: 'osm',
        googleMapsApiKey: 'example-unused-key',
      );
      expect(config.provider, JourneyMapProvider.osm);
    },
  );

  test('provider and key whitespace are normalized', () {
    final config = JourneyMapConfig.fromValues(
      provider: ' GOOGLE ',
      googleMapsApiKey: ' example-platform-key ',
    );
    expect(config.googleMapsApiKey, 'example-platform-key');
    expect(config.usesGoogle, isTrue);
    expect(
      JourneyMapConfig.fromValues(googleMapsApiKey: '  ').provider,
      JourneyMapProvider.osm,
    );
  });

  test(
    'unknown provider names are rejected instead of silently misconfigured',
    () {
      expect(
        () => JourneyMapConfig.fromValues(provider: 'ip-map'),
        throwsArgumentError,
      );
    },
  );

  test(
    'advanced markers have the demo map ID or a configured platform map ID',
    () {
      expect(JourneyMapConfig.fromValues().googleMapId, 'DEMO_MAP_ID');
      expect(
        JourneyMapConfig.fromValues(googleMapId: ' platform-map ').googleMapId,
        'platform-map',
      );
      expect(
        JourneyMapConfig.fromValues(googleMapId: ' ').googleMapId,
        'DEMO_MAP_ID',
      );
    },
  );
}
