import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ov_chronicles/core/navigation_motion.dart';
import 'package:ov_chronicles/widgets/common.dart';

Finder _nav() => find.byKey(const ValueKey('floating-nav-surface'));
Finder _indicator() => find.byKey(const ValueKey('floating-nav-indicator'));
Finder _tab(String name) => find.byKey(ValueKey('nav-$name'));
Finder _screen(String name) => find.byKey(ValueKey('screen-$name'));
Finder _icon(String name) =>
    find.descendant(of: _tab(name), matching: find.byType(Icon));

GoRouter _router({String initialLocation = '/steppe'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppNavigationShell(
        activeTab: switch (state.uri.path) {
          '/inscribe/place' => 'inscribe',
          '/scrolls' => 'scrolls',
          '/profile' => 'profile',
          _ => 'steppe',
        },
        child: child,
      ),
      routes: [
        for (final entry in const {
          '/steppe': 'steppe',
          '/inscribe/place': 'inscribe',
          '/scrolls': 'scrolls',
          '/profile': 'profile',
          '/field': 'field',
        }.entries)
          ovRoute(
            path: entry.key,
            builder: (_, _) => ColoredBox(
              key: ValueKey('screen-${entry.value}'),
              color: Colors.white,
              child: Center(child: Text(entry.value)),
            ),
          ),
      ],
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  GoRouter router, {
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the same navigation bar stays fixed while page content moves', (
    tester,
  ) async {
    final router = _router();
    await _mount(tester, router);
    final navElement = tester.element(_nav());
    final navRect = tester.getRect(_nav());
    final pageOrigin = tester.getTopLeft(_screen('steppe'));
    final iconElements = {
      for (final name in ['steppe', 'inscribe', 'scrolls', 'profile'])
        name: tester.element(_icon(name)),
    };
    final iconRects = {
      for (final name in iconElements.keys) name: tester.getRect(_icon(name)),
    };

    await tester.tap(_tab('scrolls'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    expect(tester.element(_nav()), same(navElement));
    expect(tester.getRect(_nav()), navRect);
    for (final name in iconElements.keys) {
      expect(tester.element(_icon(name)), same(iconElements[name]));
      expect(tester.getRect(_icon(name)), iconRects[name]);
    }
    expect(
      tester.getTopLeft(_screen('scrolls')).dy,
      greaterThan(pageOrigin.dy),
    );
    expect(_indicator(), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_screen('scrolls')), pageOrigin);
    expect(tester.getRect(_nav()), navRect);
    expect(tester.element(_nav()), same(navElement));
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one yellow capsule slides through the space between tabs', (
    tester,
  ) async {
    final router = _router();
    await _mount(tester, router);
    final indicatorElement = tester.element(_indicator());
    final initial = tester.getRect(_indicator());
    final destinationX = tester.getCenter(_tab('profile')).dx;

    await tester.tap(_tab('profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final intermediate = tester.getRect(_indicator());
    expect(_indicator(), findsOneWidget);
    expect(tester.element(_indicator()), same(indicatorElement));
    expect(intermediate.center.dx, greaterThan(initial.center.dx));
    expect(intermediate.center.dx, lessThan(destinationX));
    expect(intermediate.top, initial.top);
    expect(intermediate.width, closeTo(initial.width, .001));
    expect(intermediate.height, closeTo(initial.height, .001));

    await tester.pumpAndSettle();
    expect(tester.getCenter(_indicator()).dx, closeTo(destinationX, .1));
    expect(tester.element(_indicator()), same(indicatorElement));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid tab changes finish at the last page and selection', (
    tester,
  ) async {
    final router = _router();
    await _mount(tester, router);
    final navElement = tester.element(_nav());
    final navRect = tester.getRect(_nav());

    for (final name in ['scrolls', 'profile', 'inscribe', 'steppe', 'scrolls']) {
      await tester.tap(_tab(name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 35));
      expect(tester.element(_nav()), same(navElement));
      expect(tester.getRect(_nav()), navRect);
      expect(_indicator(), findsOneWidget);
    }
    await tester.pumpAndSettle();

    expect(_screen('scrolls'), findsOneWidget);
    expect(_screen('steppe'), findsNothing);
    expect(_screen('profile'), findsNothing);
    expect(_screen('inscribe'), findsNothing);
    expect(
      tester.getCenter(_indicator()).dx,
      closeTo(tester.getCenter(_tab('scrolls')).dx, .1),
    );
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion updates the page and capsule immediately', (
    tester,
  ) async {
    final router = _router();
    await _mount(tester, router, reducedMotion: true);
    final navRect = tester.getRect(_nav());
    final pageOrigin = tester.getTopLeft(_screen('steppe'));

    await tester.tap(_tab('profile'));
    await tester.pump();
    await tester.pump();

    expect(tester.getRect(_nav()), navRect);
    expect(tester.getTopLeft(_screen('profile')), pageOrigin);
    expect(
      tester.getCenter(_indicator()).dx,
      closeTo(tester.getCenter(_tab('profile')).dx, .1),
    );
    final route = ModalRoute.of(tester.element(_screen('profile')))!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.animation!.isCompleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selected Steppe tab returns from Field to its root page', (
    tester,
  ) async {
    final router = _router(initialLocation: '/field');
    await _mount(tester, router);
    final navElement = tester.element(_nav());
    final indicatorRect = tester.getRect(_indicator());

    await tester.tap(_tab('steppe'));
    await tester.pumpAndSettle();

    expect(_screen('field'), findsNothing);
    expect(_screen('steppe'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/steppe');
    expect(tester.element(_nav()), same(navElement));
    expect(tester.getRect(_indicator()), indicatorRect);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
