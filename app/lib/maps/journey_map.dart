import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'google_maps_loader.dart';
import 'map_config.dart';

/// Keeps screen controls independent from the map provider. A requested camera
/// position is retained while a map is loading or its provider is changing.
class JourneyMapController {
  void Function(LatLng, double)? _move;
  (LatLng, double)? _lastRequest;
  Object? _owner;
  bool _disposed = false;

  void move(LatLng position, double zoom) {
    if (_disposed) return;
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !zoom.isFinite) {
      throw ArgumentError('The map camera must use finite coordinates.');
    }
    final safeZoom = zoom.clamp(3.0, 18.0).toDouble();
    _lastRequest = (position, safeZoom);
    _move?.call(position, safeZoom);
  }

  void _attach(Object owner, void Function(LatLng, double) move) {
    if (_disposed) return;
    _owner = owner;
    _move = move;
    final request = _lastRequest;
    if (request != null) move(request.$1, request.$2);
  }

  void _detach(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _move = null;
    }
  }

  void dispose() {
    _disposed = true;
    _move = null;
    _owner = null;
    _lastRequest = null;
  }
}

/// An online map with provider attribution, places, an illustrative route and
/// an optional position supplied by the screen's explicit location request.
/// The parent must give this widget bounded width and height.
class JourneyMap extends StatefulWidget {
  const JourneyMap({
    super.key,
    required this.sites,
    required this.selectedSiteId,
    required this.onSiteTap,
    required this.controller,
    this.userPosition,
  });

  final List<Site> sites;
  final String selectedSiteId;
  final ValueChanged<String> onSiteTap;
  final LatLng? userPosition;
  final JourneyMapController controller;

  @override
  State<JourneyMap> createState() => _JourneyMapState();
}

class _JourneyMapState extends State<JourneyMap> {
  static const _initialPosition = LatLng(47.02, 102.4);
  static const _initialZoom = 9.0;

  final _config = JourneyMapConfig.environment;
  final _osmController = osm.MapController();
  google.GoogleMapController? _googleController;
  google.BitmapDescriptor _selectedPin = google.BitmapDescriptor.defaultMarker;
  google.BitmapDescriptor _sitePin = google.BitmapDescriptor.defaultMarker;
  StreamSubscription<void>? _authFailureSubscription;
  Future<void>? _googleReady;
  bool _useOsmFallback = false;
  bool _googleFailed = false;
  bool _tileError = false;
  bool _osmReady = false;

  bool get _usesGoogle => _config.usesGoogle && !_useOsmFallback;

  @override
  void initState() {
    super.initState();
    if (_config.usesGoogle) {
      _authFailureSubscription = googleMapsAuthFailures.listen((_) {
        if (mounted && _usesGoogle) {
          widget.controller._detach(this);
          setState(() => _googleFailed = true);
        }
      });
      _googleReady = Future.wait<void>([
        ensureGoogleMapsLoaded(_config.googleMapsApiKey),
        _loadMarkerIcons(),
      ]).then((_) {});
    }
  }

  @override
  void didUpdateWidget(covariant JourneyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach(this);
      if (_usesGoogle && !_googleFailed && _googleController != null) {
        widget.controller._attach(this, _moveGoogle);
      } else if (!_usesGoogle && _osmReady) {
        widget.controller._attach(this, _moveOsm);
      }
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _authFailureSubscription?.cancel();
    // The GoogleMap widget disposes its own platform controller.
    _googleController = null;
    _osmController.dispose();
    super.dispose();
  }

  void _moveGoogle(LatLng position, double zoom) {
    final controller = _googleController;
    if (!mounted || !_usesGoogle || _googleFailed || controller == null) return;
    unawaited(
      controller
          .animateCamera(
            google.CameraUpdate.newLatLngZoom(
              google.LatLng(position.latitude, position.longitude),
              zoom,
            ),
          )
          .catchError((Object _) {
            if (mounted && _usesGoogle) {
              widget.controller._detach(this);
              setState(() => _googleFailed = true);
            }
          }),
    );
  }

  void _moveOsm(LatLng position, double zoom) {
    if (!mounted || _usesGoogle || !_osmReady) return;
    _osmController.move(position, zoom);
  }

  void _showOsm() {
    widget.controller._detach(this);
    setState(() => _useOsmFallback = true);
    // GoogleMap owns its platform-view lifecycle and is disposed on removal.
    _googleController = null;
  }

  Future<void> _loadMarkerIcons() async {
    final icons = await Future.wait([
      _pinIcon(OvColors.gold),
      _pinIcon(OvColors.green),
    ]);
    _selectedPin = icons[0];
    _sitePin = icons[1];
  }

  // PNG pins work with AdvancedMarker on web and native SDKs. PinConfig has a
  // known iOS rendering issue, so the same small code-drawn asset is used here.
  Future<google.BitmapDescriptor> _pinIcon(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(2);
    final outline = ui.Path()
      ..moveTo(16, 42)
      ..cubicTo(13, 36, 2, 26, 2, 16)
      ..cubicTo(2, 8, 8, 2, 16, 2)
      ..cubicTo(24, 2, 30, 8, 30, 16)
      ..cubicTo(30, 26, 19, 36, 16, 42)
      ..close();
    canvas.drawPath(outline, Paint()..color = color);
    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(const Offset(16, 16), 5, Paint()..color = OvColors.cream);
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 88);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Map marker is unavailable.');
    return google.BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      imagePixelRatio: 2,
      width: 32,
      height: 44,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesGoogle) return _buildOsm();
    return FutureBuilder<void>(
      future: _googleReady,
      builder: (context, snapshot) {
        if (_googleFailed || snapshot.hasError) return _googleError();
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: OvColors.cream,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading Google Maps…'),
                ],
              ),
            ),
          );
        }
        return _buildGoogle();
      },
    );
  }

  Widget _googleError() => ColoredBox(
    color: OvColors.cream,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 36, color: OvColors.green),
            const SizedBox(height: 10),
            const Text(
              'Google Maps is unavailable. You can still explore the places.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _showOsm,
              child: const Text('Use OpenStreetMap'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildGoogle() => google.GoogleMap(
    initialCameraPosition: const google.CameraPosition(
      target: google.LatLng(47.02, 102.4),
      zoom: _initialZoom,
    ),
    onMapCreated: (controller) {
      if (!mounted || !_usesGoogle || _googleFailed) return;
      _googleController = controller;
      widget.controller._attach(this, _moveGoogle);
    },
    mapType: google.MapType.terrain,
    mapId: _config.googleMapId,
    markerType: google.GoogleMapMarkerType.advancedMarker,
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    compassEnabled: false,
    mapToolbarEnabled: false,
    zoomControlsEnabled: false,
    rotateGesturesEnabled: false,
    tiltGesturesEnabled: false,
    minMaxZoomPreference: const google.MinMaxZoomPreference(3, 18),
    markers: {
      for (final site in widget.sites)
        google.AdvancedMarker(
          markerId: google.MarkerId('site-${site.id}'),
          position: google.LatLng(site.lat, site.lng),
          icon: site.id == widget.selectedSiteId ? _selectedPin : _sitePin,
          infoWindow: google.InfoWindow(title: site.name, snippet: site.era),
          onTap: () => widget.onSiteTap(site.id),
        ),
    },
    circles: {
      if (widget.userPosition case final position?)
        google.Circle(
          circleId: const google.CircleId('user-position'),
          center: google.LatLng(position.latitude, position.longitude),
          radius: 40,
          fillColor: Colors.blue.shade700,
          strokeColor: Colors.white,
          strokeWidth: 3,
          zIndex: 1,
        ),
    },
    polylines: {
      google.Polyline(
        polylineId: const google.PolylineId('journey-preview'),
        points: widget.sites
            .map((site) => google.LatLng(site.lat, site.lng))
            .toList(),
        color: OvColors.green.withValues(alpha: .65),
        width: 3,
      ),
    },
  );

  Widget _buildOsm() => Stack(
    children: [
      osm.FlutterMap(
        mapController: _osmController,
        options: osm.MapOptions(
          initialCenter: _initialPosition,
          initialZoom: _initialZoom,
          minZoom: 3,
          maxZoom: 18,
          onMapReady: () {
            if (!mounted || _usesGoogle) return;
            _osmReady = true;
            widget.controller._attach(this, _moveOsm);
          },
        ),
        children: [
          osm.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'mn.ov.ov_chronicles',
            maxZoom: 18,
            errorTileCallback: (_, _, _) {
              if (!_tileError && mounted) {
                setState(() => _tileError = true);
              }
            },
          ),
          osm.PolylineLayer(
            polylines: [
              osm.Polyline(
                points: widget.sites
                    .map((site) => LatLng(site.lat, site.lng))
                    .toList(),
                color: OvColors.green.withValues(alpha: .65),
                strokeWidth: 3,
              ),
            ],
          ),
          osm.MarkerLayer(
            markers: [
              for (final site in widget.sites)
                osm.Marker(
                  point: LatLng(site.lat, site.lng),
                  width: 46,
                  height: 46,
                  child: IconButton(
                    tooltip: site.name,
                    style: IconButton.styleFrom(
                      backgroundColor: widget.selectedSiteId == site.id
                          ? OvColors.gold
                          : OvColors.green,
                      foregroundColor: widget.selectedSiteId == site.id
                          ? OvColors.night
                          : OvColors.cream,
                    ),
                    onPressed: () => widget.onSiteTap(site.id),
                    icon: const Icon(Icons.place_outlined),
                  ),
                ),
              if (widget.userPosition case final position?)
                osm.Marker(
                  point: position,
                  width: 28,
                  height: 28,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade700,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Material(
              color: const Color(0xEEFFFFFF),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: OvColors.ink),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      if (_tileError)
        const Align(
          alignment: Alignment.topCenter,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Map tiles unavailable. The site list still works.'),
            ),
          ),
        ),
    ],
  );
}
