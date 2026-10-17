import 'package:geolocator/geolocator.dart';

/// An arrival requires a fix whose reported uncertainty is at most this large.
const double arrivalMaxAccuracyMeters = 100;

/// Whether a recent device/browser fix can be displayed on the map.
///
/// A usable fix does not identify its underlying source as GPS. A small amount
/// of future clock skew is tolerated, but stale or malformed fixes are ignored.
bool isUsableMapPosition(Position position, {DateTime? now}) {
  if (!_validCoordinates(position.latitude, position.longitude) ||
      !position.accuracy.isFinite ||
      position.accuracy < 0) {
    return false;
  }
  final age = (now ?? DateTime.now()).difference(position.timestamp);
  return age >= const Duration(seconds: -10) &&
      age <= const Duration(minutes: 2);
}

/// Whether the reported fix and its uncertainty fit inside an arrival area.
///
/// An approximate position may still be displayed without triggering arrival.
/// This conservative check uses the provider's reported accuracy radius; it
/// cannot guarantee the user's actual location or infer a GPS source.
bool isConfidentArrival(
  Position position, {
  required double siteLat,
  required double siteLng,
  DateTime? now,
  double radiusMeters = 300,
}) {
  if (!isUsableMapPosition(position, now: now) ||
      position.accuracy > arrivalMaxAccuracyMeters ||
      !_validCoordinates(siteLat, siteLng) ||
      !radiusMeters.isFinite ||
      radiusMeters <= 0) {
    return false;
  }
  final distance = Geolocator.distanceBetween(
    position.latitude,
    position.longitude,
    siteLat,
    siteLng,
  );
  return distance.isFinite && distance + position.accuracy <= radiusMeters;
}

bool _validCoordinates(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
