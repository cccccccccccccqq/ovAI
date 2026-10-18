import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum OvPageMotion { forward, tab, overlay, fade }

/// All routes share the same restrained timing and easing on mobile and web.
GoRoute ovRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) {
  final motion = switch (path) {
    '/steppe' || '/inscribe/place' || '/scrolls' || '/profile' => OvPageMotion.tab,
    '/share/:id' || '/geofence' => OvPageMotion.overlay,
    '/welcome' || '/writing' || '/demo/:templateId' => OvPageMotion.fade,
    _ => OvPageMotion.forward,
  };
  return GoRoute(
    path: path,
    pageBuilder: (context, state) {
      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      final duration = switch (motion) {
        OvPageMotion.tab => const Duration(milliseconds: 220),
        OvPageMotion.overlay => const Duration(milliseconds: 320),
        OvPageMotion.fade => const Duration(milliseconds: 240),
        OvPageMotion.forward => const Duration(milliseconds: 300),
      };
      // Keep each push instance distinct and also animate a new story ID when
      // replacing /reader/:id. Query-only updates retain their existing state.
      final identity = '${state.pageKey.value}:${state.uri.path}';
      return CustomTransitionPage<void>(
        key: ValueKey(identity),
        name: state.name ?? state.uri.path,
        restorationId: identity,
        transitionDuration: reducedMotion ? Duration.zero : duration,
        reverseTransitionDuration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 240),
        child: RepaintBoundary(child: builder(context, state)),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            OvRouteTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              motion: motion,
              child: child,
            ),
      );
    },
  );
}

class OvRouteTransition extends StatelessWidget {
  const OvRouteTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.motion,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final OvPageMotion motion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    // A symmetric curve also keeps reversing an interrupted transition smooth.
    final eased = animation.drive(CurveTween(curve: Curves.easeInOutCubic));
    final covered = secondaryAnimation.drive(
      CurveTween(curve: Curves.easeInOutCubic),
    );
    final origin = switch (motion) {
      OvPageMotion.forward => const Offset(.065, 0),
      OvPageMotion.tab => const Offset(0, .012),
      OvPageMotion.overlay => const Offset(0, .065),
      OvPageMotion.fade => Offset.zero,
    };
    final foreground = SlideTransition(
      position: eased.drive(Tween(begin: origin, end: Offset.zero)),
      textDirection: Directionality.of(context),
      child: FadeTransition(
        // Tab replacement removes the old route. Keep its successor almost
        // opaque from the first frame, avoiding a flash of the app background.
        opacity: eased.drive(
          Tween(begin: motion == OvPageMotion.tab ? .9 : 0.0, end: 1.0),
        ),
        child: child,
      ),
    );
    if (motion != OvPageMotion.forward) return foreground;
    return SlideTransition(
      position: covered.drive(
        Tween(begin: Offset.zero, end: const Offset(-.018, 0)),
      ),
      textDirection: Directionality.of(context),
      child: foreground,
    );
  }
}
