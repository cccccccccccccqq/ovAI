import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../maps/google_maps_loader.dart';
import '../maps/map_config.dart';
import 'chapter_models.dart';

/// Circles indicate research regions, never exact birth sites or travel paths.
class ChapterMap extends StatefulWidget {
  const ChapterMap({
    super.key,
    required this.places,
    required this.selectedPlaceId,
    required this.follow,
    required this.onUserPan,
  });
  final Map<String, HistoricalPlace> places;
  final String? selectedPlaceId;
  final bool follow;
  final VoidCallback onUserPan;
  @override
  State<ChapterMap> createState() => _ChapterMapState();
}

class _ChapterMapState extends State<ChapterMap> {
  final _osm = osm.MapController();
  final _config = JourneyMapConfig.environment;
  google.GoogleMapController? _google;
  Future<void>? _googleReady;
  StreamSubscription<void>? _authFailure;
  bool _googleFailed = false;
  bool _fallback = false;
  bool _ready = false;
  bool _movingByCue = true;
  bool _tileError = false;
  HistoricalPlace get _selected =>
      widget.places[widget.selectedPlaceId] ?? widget.places.values.first;
  bool get _usesGoogle => _config.usesGoogle && !_fallback;

  @override
  void initState() {
    super.initState();
    if (_config.usesGoogle) {
      _googleReady = ensureGoogleMapsLoaded(_config.googleMapsApiKey);
      _authFailure = googleMapsAuthFailures.listen((_) {
        if (mounted) setState(() => _googleFailed = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChapterMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.follow &&
        (oldWidget.selectedPlaceId != widget.selectedPlaceId ||
            !oldWidget.follow)) {
      _move();
    }
  }

  void _move() {
    if (!_ready || !widget.follow) return;
    if (_usesGoogle) {
      _movingByCue = true;
      unawaited(
        _google
            ?.animateCamera(
              google.CameraUpdate.newLatLngZoom(
                google.LatLng(_selected.latitude, _selected.longitude),
                _selected.overviewZoom,
              ),
            )
            .catchError((Object _) {
              _movingByCue = false;
            }),
      );
    } else {
      _osm.move(
        LatLng(_selected.latitude, _selected.longitude),
        _selected.overviewZoom,
      );
    }
  }

  @override
  void dispose() {
    _authFailure?.cancel();
    _osm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.places.isEmpty) {
      return const Center(child: Text('No place information is available.'));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: _usesGoogle
                ? FutureBuilder<void>(
                    future: _googleReady,
                    builder: (context, snapshot) {
                      if (_googleFailed || snapshot.hasError) {
                        return ColoredBox(
                          color: OvColors.cream,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Google Maps could not be loaded.',
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _fallback = true;
                                      _ready = false;
                                    }),
                                    child: const Text('Use OpenStreetMap'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _googleMap();
                    },
                  )
                : _osmMap(),
          ),
          Positioned(
            left: 10,
            right: 10,
            top: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: OvColors.cream.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Research regions · exact locations are uncertain',
                  style: TextStyle(fontSize: 10, color: OvColors.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleMap() => google.GoogleMap(
    initialCameraPosition: google.CameraPosition(
      target: google.LatLng(_selected.latitude, _selected.longitude),
      zoom: _selected.overviewZoom,
    ),
    mapId: _config.googleMapId,
    myLocationButtonEnabled: false,
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
    circles: {
      for (final place in widget.places.values)
        google.Circle(
          circleId: google.CircleId(place.id),
          center: google.LatLng(place.latitude, place.longitude),
          radius: place.radiusMeters,
          fillColor:
              (place.id == widget.selectedPlaceId
                      ? OvColors.gold
                      : OvColors.green)
                  .withValues(
                    alpha: place.id == widget.selectedPlaceId ? .18 : .05,
                  ),
          strokeColor: place.id == widget.selectedPlaceId
              ? OvColors.gold
              : OvColors.green.withValues(alpha: .4),
          strokeWidth: place.id == widget.selectedPlaceId ? 2 : 1,
        ),
    },
    onMapCreated: (controller) {
      _google = controller;
      _movingByCue = true;
      _ready = true;
    },
    onCameraIdle: () => _movingByCue = false,
    onCameraMoveStarted: () {
      if (_ready && !_movingByCue) widget.onUserPan();
    },
  );

  Widget _osmMap() => Stack(
    children: [
      osm.FlutterMap(
        mapController: _osm,
        options: osm.MapOptions(
          initialCenter: LatLng(_selected.latitude, _selected.longitude),
          initialZoom: _selected.overviewZoom,
          minZoom: 3,
          maxZoom: 14,
          onMapReady: () => _ready = true,
          onPositionChanged: (_, hasGesture) {
            if (hasGesture) widget.onUserPan();
          },
        ),
        children: [
          osm.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'mn.ov.ovChronicles',
            errorTileCallback: (_, _, _) {
              if (!_tileError && mounted) setState(() => _tileError = true);
            },
          ),
          osm.CircleLayer(
            circles: [
              for (final place in widget.places.values)
                osm.CircleMarker(
                  point: LatLng(place.latitude, place.longitude),
                  radius: place.radiusMeters,
                  useRadiusInMeter: true,
                  color:
                      (place.id == widget.selectedPlaceId
                              ? OvColors.gold
                              : OvColors.green)
                          .withValues(
                            alpha: place.id == widget.selectedPlaceId
                                ? .18
                                : .05,
                          ),
                  borderColor: place.id == widget.selectedPlaceId
                      ? OvColors.gold
                      : OvColors.green.withValues(alpha: .4),
                  borderStrokeWidth: place.id == widget.selectedPlaceId ? 2 : 1,
                ),
            ],
          ),
          osm.RichAttributionWidget(
            attributions: [
              osm.TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
              ),
            ],
          ),
        ],
      ),
      if (_tileError)
        const Positioned(
          left: 8,
          right: 8,
          bottom: 30,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'A network connection is needed to load the base map.',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
    ],
  );
}
