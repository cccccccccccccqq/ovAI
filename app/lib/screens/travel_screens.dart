import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../core/location_policy.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../maps/journey_map.dart';
import '../widgets/common.dart';

DateTime? _arrivalDismissedAt;

class FieldMapScreen extends StatefulWidget {
  const FieldMapScreen({super.key});
  @override
  State<FieldMapScreen> createState() => _FieldMapScreenState();
}

class _FieldMapScreenState extends State<FieldMapScreen> {
  final _map = JourneyMapController();
  StreamSubscription<Position>? _positions;
  LatLng? _position;
  bool _live = false;
  bool _locating = false;
  double? _accuracy;
  int _positionGeneration = 0;
  bool _centerOnNextFix = false;
  String? _locationMessage;

  @override
  void dispose() {
    _positionGeneration++;
    unawaited(_positions?.cancel());
    _map.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    if (_locating) return;
    final generation = ++_positionGeneration;
    setState(() {
      _locating = true;
      _centerOnNextFix = true;
      _locationMessage = null;
    });
    try {
      await _positions?.cancel();
      _positions = null;
      if (!mounted || generation != _positionGeneration) return;
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted || generation != _positionGeneration) return;
      if (!serviceEnabled) {
        throw StateError(
          'Location services are off. Enable them in device settings, or use the demo arrival below.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (!mounted || generation != _positionGeneration) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted || generation != _positionGeneration) return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location access was declined. You can still explore every place and try a demo arrival.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted || generation != _positionGeneration) return;
      _setPosition(position, recenter: true);
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen(
            (position) {
              if (generation == _positionGeneration) _setPosition(position);
            },
            onError: (_) {
              if (mounted && generation == _positionGeneration) {
                setState(
                  () => _locationMessage =
                      'Location updates stopped. Tap Use my location to retry.',
                );
              }
            },
          );
    } catch (error) {
      if (mounted && generation == _positionGeneration) {
        setState(
          () => _locationMessage = error is StateError
              ? error.message.toString()
              : 'Unable to find your location. Try again or use demo arrival.',
        );
      }
    } finally {
      if (mounted && generation == _positionGeneration) {
        setState(() => _locating = false);
      }
    }
  }

  void _setPosition(Position position, {bool recenter = false}) {
    if (!mounted) return;
    if (!isUsableMapPosition(position)) {
      setState(() => _locationMessage = 'Waiting for a fresh device location.');
      return;
    }
    final app = AppScope.of(context);
    setState(() {
      _position = LatLng(position.latitude, position.longitude);
      _live = true;
      _accuracy = position.accuracy;
      _locationMessage = position.accuracy > arrivalMaxAccuracyMeters
          ? 'Your location is approximate. A more accurate fix is needed for nearby arrival.'
          : null;
    });
    if ((recenter || _centerOnNextFix) && !app.offline) {
      _map.move(_position!, 13);
    }
    _centerOnNextFix = false;
    if (_arrivalDismissedAt != null &&
        DateTime.now().difference(_arrivalDismissedAt!) <
            const Duration(minutes: 10)) {
      return;
    }
    for (final site in app.sites) {
      if (site.isApproximate) continue;
      if (isConfidentArrival(position, siteLat: site.lat, siteLng: site.lng)) {
        _arrivalDismissedAt = DateTime.now();
        unawaited(app.selectSite(site.id));
        context.push('/geofence?mode=live');
        break;
      }
    }
  }

  Future<void> _demoArrival(Site site) async {
    final app = AppScope.of(context);
    _positionGeneration++;
    await _positions?.cancel();
    _positions = null;
    await app.selectSite(site.id);
    if (!mounted) return;
    setState(() {
      _live = false;
      _locating = false;
      _accuracy = null;
      _centerOnNextFix = false;
      _locationMessage = null;
      _position = LatLng(site.lat + .0007, site.lng);
    });
    await context.push('/geofence?mode=demo');
    _arrivalDismissedAt = DateTime.now();
  }

  Future<void> _openDirections(Site site) async {
    if (site.isApproximate) return;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': '${site.lat},${site.lng}',
          'travelmode': 'driving',
        }),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // The place list stays usable when no external browser/maps app opens.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Maps could not be opened. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selected = app.selectedSite;
    return AppScaffold(
      title: 'Out on the steppe',
      eyebrow: 'FIELD MODE',
      actions: [
        IconButton(
          tooltip: 'Offline packs',
          onPressed: () => context.push('/downloads'),
          icon: const Icon(Icons.download_for_offline_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              DemoBadge(text: _live ? 'DEVICE LOCATION' : 'DEMO ROUTE'),
              TextButton(
                onPressed: () => context.go('/steppe'),
                child: const Text('Studio view'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 330,
              child: app.offline
                  ? DemoMap(
                      selectedSiteId: selected.id,
                      onSiteTap: (id) => app.selectSite(id),
                    )
                  : JourneyMap(
                      controller: _map,
                      sites: app.sites,
                      selectedSiteId: selected.id,
                      userPosition: _position,
                      onSiteTap: (id) => unawaited(app.selectSite(id)),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            app.offline
                ? 'Offline demo overview · no map tiles required'
                : 'Preview route between sites · not turn-by-turn directions',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          PillButton(
            label: _locating ? 'Finding your location…' : 'Use my location',
            icon: Icons.my_location,
            busy: _locating,
            secondary: true,
            onPressed: _locating ? null : _requestLocation,
          ),
          if (_locationMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _locationMessage!,
                style: const TextStyle(color: OvColors.red),
              ),
            ),
          if (_live && _accuracy != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Location accuracy: ±${_accuracy!.ceil()} m',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Along your journey',
            subtitle: 'Explore places and historical regions',
          ),
          const SizedBox(height: 12),
          for (final site in app.sites)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppImage(path: site.image, width: 56, height: 56),
                ),
                title: Text(site.name),
                subtitle: Text(
                  site.locationNote ??
                      (_position == null
                          ? site.era
                          : '${(Geolocator.distanceBetween(_position!.latitude, _position!.longitude, site.lat, site.lng) / 1000).toStringAsFixed(1)} km · ${_live ? 'from your location' : 'from demo marker'}'),
                ),
                trailing: const Icon(Icons.chevron_right),
                selected: selected.id == site.id,
                onTap: () {
                  app.selectSite(site.id);
                  if (!app.offline) {
                    _map.move(
                      LatLng(site.lat, site.lng),
                      site.isApproximate ? 7 : 13,
                    );
                  }
                },
              ),
            ),
          const SizedBox(height: 20),
          if (!selected.isApproximate)
            PillButton(
              label: 'Directions in Google Maps',
              icon: Icons.directions_outlined,
              secondary: true,
              onPressed: () => _openDirections(selected),
            ),
          if (!selected.isApproximate) const SizedBox(height: 12),
          PillButton(
            label: selected.isApproximate
                ? 'Explore this region'
                : 'Try arrival at ${selected.name}',
            icon: selected.isApproximate
                ? Icons.explore_outlined
                : Icons.near_me_outlined,
            onPressed: selected.isApproximate
                ? () => context.go('/steppe')
                : () => _demoArrival(selected),
          ),
          const SizedBox(height: 8),
          Text(
            selected.locationNote ??
                'Demo arrival uses a prepared location. Your device location is only requested when you tap Use my location.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class GeofenceScreen extends StatelessWidget {
  const GeofenceScreen({super.key, this.live = false});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final site = app.selectedSite;
    return AppScaffold(
      title: 'A story is close',
      eyebrow: live ? 'NEARBY PLACE' : 'DEMO ARRIVAL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AppImage(
              path: site.image,
              height: 260,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 24),
          DemoBadge(text: live ? 'WITHIN 300 M' : 'PREPARED LOCATION'),
          const SizedBox(height: 16),
          Text(
            'Welcome to\n${site.name}.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 14),
          Text(site.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          PillButton(
            label: 'Read this place',
            icon: Icons.menu_book_outlined,
            onPressed: () async {
              final story = await app.createChronicle(
                templateId: app.defaultTemplateForSite(site.id).id,
              );
              if (context.mounted) context.push('/reader/${story.id}');
            },
          ),
          const SizedBox(height: 12),
          PillButton(
            label: 'Write your own path',
            icon: Icons.edit_outlined,
            secondary: true,
            onPressed: () => context.push('/inscribe/place'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                _arrivalDismissedAt = DateTime.now();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/field');
                }
              },
              child: const Text('Keep exploring'),
            ),
          ),
        ],
      ),
    );
  }
}
