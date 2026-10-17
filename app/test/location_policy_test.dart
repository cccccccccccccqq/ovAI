import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ov_chronicles/core/location_policy.dart';

final _now = DateTime.utc(2026, 10, 17, 12);

Position _fix({
  double latitude = 0,
  double longitude = 0,
  double accuracy = 10,
  DateTime? timestamp,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: timestamp ?? _now,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

bool _arrived(Position fix, {double radius = 300}) => isConfidentArrival(
  fix,
  siteLat: 0,
  siteLng: 0,
  now: _now,
  radiusMeters: radius,
);

void main() {
  group('Map position validation', () {
    test(
      'approximate current fixes can be displayed without asserting GPS',
      () {
        final approximate = _fix(accuracy: 2000);
        expect(isUsableMapPosition(approximate, now: _now), isTrue);
        expect(_arrived(approximate), isFalse);
      },
    );

    test(
      'rejects invalid coordinates and nonfinite or negative uncertainty',
      () {
        final malformed = [
          _fix(latitude: double.nan),
          _fix(longitude: double.infinity),
          _fix(latitude: -90.001),
          _fix(latitude: 90.001),
          _fix(longitude: -180.001),
          _fix(longitude: 180.001),
          _fix(accuracy: double.nan),
          _fix(accuracy: double.infinity),
          _fix(accuracy: -1),
        ];
        for (final fix in malformed) {
          expect(isUsableMapPosition(fix, now: _now), isFalse);
          expect(_arrived(fix), isFalse);
        }
        expect(
          isUsableMapPosition(_fix(latitude: -90, longitude: -180), now: _now),
          isTrue,
        );
        expect(
          isUsableMapPosition(_fix(latitude: 90, longitude: 180), now: _now),
          isTrue,
        );
      },
    );

    test('rejects stale fixes and allows only small future clock skew', () {
      final oldest = _fix(timestamp: _now.subtract(const Duration(minutes: 2)));
      final skewed = _fix(timestamp: _now.add(const Duration(seconds: 10)));
      expect(isUsableMapPosition(oldest, now: _now), isTrue);
      expect(isUsableMapPosition(skewed, now: _now), isTrue);

      for (final fix in [
        _fix(timestamp: _now.subtract(const Duration(seconds: 121))),
        _fix(timestamp: _now.add(const Duration(seconds: 11))),
      ]) {
        expect(isUsableMapPosition(fix, now: _now), isFalse);
        expect(_arrived(fix), isFalse);
      }
    });
  });

  group('Conservative nearby arrival', () {
    test('accepts a precise fix well inside and rejects a fix outside', () {
      expect(_arrived(_fix(longitude: .001)), isTrue);
      expect(_arrived(_fix(longitude: .004)), isFalse);
    });

    test('rejects uncertainty extending beyond the arrival area', () {
      // The estimated point is about 278 m away, but the uncertainty extends
      // outside the 300 m arrival area.
      expect(_arrived(_fix(longitude: .0025, accuracy: 30)), isFalse);
      expect(_arrived(_fix(longitude: .0025, accuracy: 10)), isTrue);
    });

    test('rejects coarse fixes even with an estimate at the place itself', () {
      expect(_arrived(_fix(accuracy: arrivalMaxAccuracyMeters)), isTrue);
      expect(_arrived(_fix(accuracy: arrivalMaxAccuracyMeters + .01)), isFalse);
    });

    test('includes the exact uncertainty boundary and excludes overflow', () {
      final fix = _fix(longitude: .001, accuracy: 25);
      final uncertaintyBoundary =
          Geolocator.distanceBetween(0, .001, 0, 0) + 25;
      expect(_arrived(fix, radius: uncertaintyBoundary), isTrue);
      expect(_arrived(fix, radius: uncertaintyBoundary - .001), isFalse);
    });

    test(
      'rejects invalid arrival areas instead of producing false arrivals',
      () {
        for (final radius in [0.0, -1.0, double.nan, double.infinity]) {
          expect(_arrived(_fix(), radius: radius), isFalse);
        }
        expect(
          isConfidentArrival(
            _fix(),
            siteLat: double.nan,
            siteLng: 0,
            now: _now,
          ),
          isFalse,
        );
        expect(
          isConfidentArrival(_fix(), siteLat: 0, siteLng: 181, now: _now),
          isFalse,
        );
      },
    );
  });
}
