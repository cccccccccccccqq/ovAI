import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ov_chronicles/core/navigation_motion.dart';

Finder _screen(String name) => find.byKey(ValueKey('screen-$name'));

GoRouter _router({String initialLocation = '/steppe'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    for (final name in ['steppe', 'scrolls', 'profile', 'settings'])
      ovRoute(
        path: '/$name',
        builder: (_, _) => _Screen(name: name),
      ),
    ovRoute(
      path: '/reader/:id',
      builder: (_, state) => _Screen(name: state.pathParameters['id']!),
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  GoRouter router, {
  bool reducedMotion = false,
}) async {
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
  testWidgets('push and pop move smoothly while preserving the previous page', (
    tester,
  ) async {
    final router = _router();
    await _mount(tester, router);
    await tester.tap(find.text('Increment steppe'));
    await tester.pump();

    router.push<void>('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final entering = tester.getTopLeft(_screen('settings'));
    expect(entering.dx, greaterThan(0));
    expect(entering.dx, lessThan(tester.view.physicalSize.width));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_screen('settings')), Offset.zero);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(_screen('settings')).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(_screen('settings'), findsNothing);
    expect(tester.getTopLeft(_screen('steppe')), Offset.zero);
    expect(find.text('steppe count: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('root tab replacement animates and keeps a single page history', (
    tester,
  ) async {
    final router = _router();
    await _mount(tester, router);

    router.go('/scrolls');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(_screen('scrolls')).dy, greaterThan(0));
    expect(router.canPop(), isFalse);
    await tester.pumpAndSettle();

    expect(_screen('steppe'), findsNothing);
    expect(tester.getTopLeft(_screen('scrolls')), Offset.zero);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion shows destinations immediately without movement',
    (tester) async {
      final router = _router();
      await _mount(tester, router, reducedMotion: true);

      router.push<void>('/settings');
      await tester.pump();
      await tester.pump();
      final route = ModalRoute.of(tester.element(_screen('settings')))!;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      expect(route.animation!.isCompleted, isTrue);
      expect(tester.getTopLeft(_screen('settings')), Offset.zero);

      router.pop();
      await tester.pump();
      await tester.pump();
      expect(_screen('settings'), findsNothing);
      expect(tester.getTopLeft(_screen('steppe')), Offset.zero);

      router.go('/scrolls');
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(_screen('scrolls')), Offset.zero);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid tab changes settle at the final requested destination', (
    tester,
  ) async {
    final router = _router();
    await _mount(tester, router);

    for (final path in ['/scrolls', '/profile', '/steppe', '/scrolls']) {
      router.go(path);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();

    expect(_screen('scrolls'), findsOneWidget);
    expect(_screen('steppe'), findsNothing);
    expect(_screen('profile'), findsNothing);
    expect(tester.getTopLeft(_screen('scrolls')), Offset.zero);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new story animates while query updates preserve page state', (
    tester,
  ) async {
    final router = _router(initialLocation: '/reader/first');
    await _mount(tester, router);
    await tester.tap(find.text('Increment first'));
    await tester.pump();

    router.go('/reader/first?source=library');
    await tester.pump();
    expect(tester.getTopLeft(_screen('first')), Offset.zero);
    expect(find.text('first count: 1'), findsOneWidget);

    router.go('/reader/second');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(_screen('second')).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(_screen('first'), findsNothing);
    expect(find.text('second count: 0'), findsOneWidget);
    expect(tester.getTopLeft(_screen('second')), Offset.zero);
    expect(tester.takeException(), isNull);
  });
}

class _Screen extends StatefulWidget {
  const _Screen({required this.name});
  final String name;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: ValueKey('screen-${widget.name}'),
    body: Column(
      children: [
        Text('${widget.name} count: $_count'),
        TextButton(
          onPressed: () => setState(() => _count++),
          child: Text('Increment ${widget.name}'),
        ),
      ],
    ),
  );
}
