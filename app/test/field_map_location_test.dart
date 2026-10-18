import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:ov_chronicles/core/app_scope.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:ov_chronicles/core/theme.dart';
import 'package:ov_chronicles/screens/travel_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _position({
  double latitude = 0,
  double longitude = 0,
  double accuracy = 15,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _DeviceLocation extends GeolocatorPlatform {
  _DeviceLocation() {
    updates = StreamController<Position>.broadcast(
      sync: true,
      onCancel: () => cancelledStreams++,
    );
  }

  late final StreamController<Position> updates;
  LocationPermission permission = LocationPermission.denied;
  Position Function() nextFix = _position;
  Completer<bool>? pendingServiceCheck;
  Completer<LocationPermission>? pendingPermissionCheck;
  Completer<LocationPermission>? pendingPermissionRequest;
  Completer<Position>? pendingFix;
  int serviceChecks = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int positionRequests = 0;
  int streamRequests = 0;
  int cancelledStreams = 0;

  @override
  Future<bool> isLocationServiceEnabled() {
    serviceChecks++;
    return pendingServiceCheck?.future ?? Future.value(true);
  }

  @override
  Future<LocationPermission> checkPermission() {
    permissionChecks++;
    return pendingPermissionCheck?.future ?? Future.value(permission);
  }

  @override
  Future<LocationPermission> requestPermission() {
    permissionRequests++;
    if (pendingPermissionRequest != null) {
      return pendingPermissionRequest!.future;
    }
    permission = LocationPermission.whileInUse;
    return Future.value(permission);
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    positionRequests++;
    return pendingFix?.future ?? Future.value(nextFix());
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamRequests++;
    return updates.stream;
  }
}

Future<({AppState state, GoRouter router})> _showFieldMap(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final state = await AppState.load();
  await state.setOffline(true);
  final router = GoRouter(
    initialLocation: '/field',
    routes: [
      GoRoute(path: '/field', builder: (_, _) => const FieldMapScreen()),
      GoRoute(
        path: '/geofence',
        builder: (_, route) => Scaffold(
          body: Text('Arrival: ${route.uri.queryParameters['mode']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp.router(
        theme: buildOvTheme(false),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (state: state, router: router);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  // A pending location fix deliberately leaves a progress indicator running.
  // Advance navigation animations without waiting for that request to finish.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _closeFieldMap(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeolocatorPlatform originalLocation;
  late _DeviceLocation device;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalLocation = GeolocatorPlatform.instance;
    device = _DeviceLocation();
    GeolocatorPlatform.instance = device;
  });

  tearDown(() async {
    GeolocatorPlatform.instance = originalLocation;
    await device.updates.close();
  });

  testWidgets('location permissions are requested only after an explicit tap', (
    tester,
  ) async {
    await _showFieldMap(tester);
    expect(device.serviceChecks, 0);
    expect(device.permissionChecks, 0);
    expect(device.permissionRequests, 0);
    expect(device.positionRequests, 0);
    expect(find.text('PREPARED ROUTE'), findsOneWidget);

    await _tap(tester, find.text('Use my location'));
    expect(device.permissionRequests, 1);
    expect(device.positionRequests, 1);
    expect(device.streamRequests, 1);
    expect(find.text('DEVICE LOCATION'), findsOneWidget);
    expect(find.text('Location accuracy: ±15 m'), findsOneWidget);
    await _closeFieldMap(tester);
  });

  testWidgets('a coarse fix at a place does not open nearby arrival', (
    tester,
  ) async {
    final fixture = await _showFieldMap(tester);
    final site = fixture.state.selectedSite;
    device.nextFix = () =>
        _position(latitude: site.lat, longitude: site.lng, accuracy: 2000);

    await _tap(tester, find.text('Use my location'));
    expect(fixture.router.routeInformationProvider.value.uri.path, '/field');
    expect(find.text('Arrival: live'), findsNothing);
    expect(find.text('Location accuracy: ±2000 m'), findsOneWidget);
    expect(
      find.text(
        'Your location is approximate. A more accurate fix is needed for nearby arrival.',
      ),
      findsOneWidget,
    );
    await _closeFieldMap(tester);
  });

  testWidgets('demo arrival cancels live updates and keeps the demo marker', (
    tester,
  ) async {
    final fixture = await _showFieldMap(tester);
    await _tap(tester, find.text('Use my location'));
    expect(device.updates.hasListener, isTrue);

    await _tap(
      tester,
      find.text('Preview arrival at ${fixture.state.selectedSite.name}'),
    );
    await tester.pumpAndSettle();
    // Stream cancellation completes asynchronously outside widget frame timing.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(device.cancelledStreams, 1);
    expect(device.updates.hasListener, isFalse);
    expect(find.text('Arrival: demo'), findsOneWidget);

    // A device update after cancellation must not replace prepared demo state.
    device.updates.add(_position(accuracy: 8));
    await tester.pump();
    fixture.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('PREPARED ROUTE'), findsOneWidget);
    expect(find.text('DEVICE LOCATION'), findsNothing);
    expect(find.textContaining('Location accuracy:'), findsNothing);
    expect(find.textContaining('from preview marker'), findsNWidgets(4));
    await _closeFieldMap(tester);
  });

  testWidgets('a pending device fix cannot override a later demo arrival', (
    tester,
  ) async {
    final fixture = await _showFieldMap(tester);
    final pending = Completer<Position>();
    device.pendingFix = pending;
    await _tap(tester, find.text('Use my location'));
    expect(device.positionRequests, 1);
    expect(find.text('Finding your location…'), findsOneWidget);

    await _tap(
      tester,
      find.text('Preview arrival at ${fixture.state.selectedSite.name}'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arrival: demo'), findsOneWidget);
    pending.complete(_position(accuracy: 8));
    await tester.pump();
    expect(device.streamRequests, 0);

    fixture.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('PREPARED ROUTE'), findsOneWidget);
    expect(find.text('DEVICE LOCATION'), findsNothing);
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.textContaining('Location accuracy:'), findsNothing);
    await _closeFieldMap(tester);
  });

  testWidgets('a late service check cannot ask permission after demo arrival', (
    tester,
  ) async {
    final fixture = await _showFieldMap(tester);
    final pending = Completer<bool>();
    device.pendingServiceCheck = pending;
    await _tap(tester, find.text('Use my location'));
    expect(device.serviceChecks, 1);
    expect(device.permissionChecks, 0);

    await _tap(
      tester,
      find.text('Preview arrival at ${fixture.state.selectedSite.name}'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arrival: demo'), findsOneWidget);
    pending.complete(true);
    await tester.pump();

    expect(device.permissionChecks, 0);
    expect(device.permissionRequests, 0);
    expect(device.positionRequests, 0);
    expect(device.streamRequests, 0);
    await _closeFieldMap(tester);
  });

  testWidgets('a late permission check cannot prompt after the map is closed', (
    tester,
  ) async {
    await _showFieldMap(tester);
    final pending = Completer<LocationPermission>();
    device.pendingPermissionCheck = pending;
    await _tap(tester, find.text('Use my location'));
    expect(device.permissionChecks, 1);
    expect(device.permissionRequests, 0);

    await _closeFieldMap(tester);
    pending.complete(LocationPermission.denied);
    await tester.pump();

    expect(device.permissionRequests, 0);
    expect(device.positionRequests, 0);
    expect(device.streamRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late permission approval cannot start location after demo arrival',
    (tester) async {
      final fixture = await _showFieldMap(tester);
      final pending = Completer<LocationPermission>();
      device.pendingPermissionRequest = pending;
      await _tap(tester, find.text('Use my location'));
      expect(device.permissionRequests, 1);
      expect(device.positionRequests, 0);

      await _tap(
        tester,
        find.text('Preview arrival at ${fixture.state.selectedSite.name}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arrival: demo'), findsOneWidget);
      pending.complete(LocationPermission.whileInUse);
      await tester.pump();

      expect(device.positionRequests, 0);
      expect(device.streamRequests, 0);
      expect(find.text('Arrival: demo'), findsOneWidget);
      await _closeFieldMap(tester);
    },
  );
}
