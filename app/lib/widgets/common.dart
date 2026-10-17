import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/models.dart';
import '../core/theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title,
    this.eyebrow,
    this.actions,
    this.dark = false,
    this.showBack = true,
    this.bottom,
    this.scroll = true,
  });
  final Widget child;
  final String? title;
  final String? eyebrow;
  final List<Widget>? actions;
  final bool dark;
  final bool showBack;
  final Widget? bottom;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final actualDark = dark || Theme.of(context).brightness == Brightness.dark;
    final theme = buildOvTheme(actualDark);
    final header =
        title != null || eyebrow != null || (actions?.isNotEmpty ?? false);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: scroll ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (header)
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBack)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filledTonal(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/steppe'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Go back',
                      style: IconButton.styleFrom(
                        backgroundColor: actualDark
                            ? OvColors.ink
                            : Colors.white,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            eyebrow!.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              letterSpacing: 1.7,
                              fontWeight: FontWeight.w600,
                              color: actualDark
                                  ? OvColors.gold
                                  : OvColors.brown,
                            ),
                          ),
                        ),
                      if (title != null)
                        Text(title!, style: theme.textTheme.headlineLarge),
                    ],
                  ),
                ),
                ...?actions,
              ],
            ),
          ),
        if (scroll) child else Expanded(child: child),
      ],
    );
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: actualDark ? OvColors.night : OvColors.cream,
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: scroll
                  ? SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      child: content,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: content,
                    ),
            ),
          ),
        ),
        bottomNavigationBar: bottom != null
            ? SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bottom != null)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            child: bottom!,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

/// Lives above the page navigator, so only its content participates in route
/// transitions. The same navigation surface and indicator survive tab changes.
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({
    super.key,
    required this.activeTab,
    required this.child,
  });

  final String activeTab;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: SafeArea(
      top: false,
      child: _FloatingNav(activeTab: activeTab),
    ),
  );
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.activeTab});
  final String activeTab;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('steppe', 'Steppe', Icons.explore_outlined, '/steppe'),
      ('inscribe', 'Inscribe', Icons.edit_outlined, '/inscribe/place'),
      ('scrolls', 'Scrolls', Icons.auto_stories_outlined, '/scrolls'),
      ('orda', 'Orda', Icons.person_outline_rounded, '/orda'),
    ];
    final selectedIndex = items.indexWhere((item) => item.$1 == activeTab);
    final motionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          key: const ValueKey('floating-nav-surface'),
          margin: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: OvColors.night,
            borderRadius: BorderRadius.circular(42),
            border: Border.all(color: Colors.white.withValues(alpha: .13)),
            boxShadow: [
              BoxShadow(
                color: OvColors.night.withValues(alpha: .18),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedAlign(
                      alignment: AlignmentDirectional(
                        -1 + 2 * selectedIndex / (items.length - 1),
                        0,
                      ),
                      duration: motionDuration,
                      curve: Curves.easeInOutCubic,
                      child: FractionallySizedBox(
                        widthFactor: 1 / items.length,
                        heightFactor: 1,
                        child: DecoratedBox(
                          key: const ValueKey('floating-nav-indicator'),
                          decoration: BoxDecoration(
                            color: OvColors.gold,
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: items.map((item) {
                    final selected = item.$1 == activeTab;
                    final foreground = selected
                        ? OvColors.night
                        : OvColors.cream.withValues(alpha: .8);
                    return Expanded(
                      child: Semantics(
                        selected: selected,
                        button: true,
                        label: item.$2,
                        child: InkWell(
                          key: ValueKey('nav-${item.$1}'),
                          onTap: () {
                            if (GoRouterState.of(context).uri.path != item.$4) {
                              context.go(item.$4);
                            }
                          },
                          borderRadius: BorderRadius.circular(32),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(item.$3, size: 23, color: foreground),
                                const SizedBox(height: 3),
                                Text(
                                  item.$2,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (icon != null && !busy)
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: Icon(icon, size: 19),
          ),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: secondary
          ? OutlinedButton(onPressed: busy ? null : onPressed, child: content)
          : FilledButton(onPressed: busy ? null : onPressed, child: content),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: OvColors.gold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    ),
  );
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.text = 'LOCAL DEMO'});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: OvColors.gold.withValues(alpha: .16),
      border: Border.all(color: OvColors.gold.withValues(alpha: .38)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.circle, size: 6, color: OvColors.gold),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Theme.of(context).brightness == Brightness.dark
                  ? OvColors.gold
                  : OvColors.brown,
            ),
          ),
        ),
      ],
    ),
  );
}

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });
  final String path;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) => Container(
      width: width,
      height: height,
      color: OvColors.green,
      alignment: Alignment.center,
      child: const Icon(
        Icons.landscape_outlined,
        color: OvColors.gold,
        size: 48,
      ),
    );
    if (path.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(path.split(',').last),
          height: height,
          width: width,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: fallback,
        );
      } catch (_) {
        return fallback(
          context,
          const FormatException('Image unavailable'),
          null,
        );
      }
    }
    return Image.asset(
      path,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: fallback,
    );
  }
}

class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.story, this.onTap});
  final Chronicle story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final site = state.siteById(story.siteId);
    final template = state.templateFor(story);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Material(
        color: OvColors.night,
        child: InkWell(
          onTap: onTap ?? () => context.push('/reader/${story.id}'),
          child: SizedBox(
            height: 350,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(path: story.image),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x140C1F14), Color(0xFA0C1F14)],
                      stops: [.15, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: OvColors.night.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'CHAPTER ${template.chapter} · PREPARED STORY',
                      style: const TextStyle(
                        color: OvColors.cream,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 9,
                  child: IconButton(
                    onPressed: () => state.toggleStoryBookmark(story.id),
                    icon: Icon(
                      story.bookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: OvColors.cream,
                    ),
                    tooltip: story.bookmarked
                        ? 'Remove bookmark'
                        : 'Bookmark story',
                    style: IconButton.styleFrom(
                      backgroundColor: OvColors.night.withValues(alpha: .6),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name.toUpperCase(),
                        style: const TextStyle(
                          color: OvColors.gold,
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: OvColors.cream,
                          fontSize: 28,
                          height: 1.13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${story.genre}  ·  ${template.readingMinutes} min read',
                        style: TextStyle(
                          color: OvColors.cream.withValues(alpha: .8),
                          fontSize: 12,
                        ),
                      ),
                      if (story.readingProgress > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: story.readingProgress,
                              minHeight: 3,
                              color: OvColors.gold,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  onTap ??
                                  () => context.push('/reader/${story.id}'),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 20,
                              ),
                              label: Text(
                                story.readingProgress > 0 &&
                                        story.readingProgress < 1
                                    ? 'Continue reading'
                                    : 'Read & listen',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: OvColors.gold,
                                foregroundColor: OvColors.night,
                                minimumSize: const Size(0, 46),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => context.push('/share/${story.id}'),
                            icon: const Icon(
                              Icons.ios_share_rounded,
                              color: OvColors.cream,
                              size: 21,
                            ),
                            tooltip: 'Share this chronicle',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: .12,
                              ),
                              minimumSize: const Size(46, 46),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DemoMap extends StatelessWidget {
  const DemoMap({
    super.key,
    this.selectedSiteId,
    this.onSiteTap,
    this.compact = false,
    this.showRoute = true,
  });
  final String? selectedSiteId;
  final ValueChanged<String>? onSiteTap;
  final bool compact;
  final bool showRoute;

  @override
  Widget build(BuildContext context) {
    final sites = AppScope.of(context).sites;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: compact ? 1.45 : 1.08,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final points = <String, Offset>{};
            // Geographic projection of the Orkhon Valley; adjacent Kharkhorin / Erdene
            // Zuu pins are displaced slightly to keep their tap targets separate.
            for (final site in sites) {
              final x = ((site.lng - 101.55) / 1.65).clamp(.12, .88);
              final y = ((47.45 - site.lat) / 1.05).clamp(.14, .84);
              points[site.id] = Offset(x * size.width, y * size.height);
            }
            if (points['kharkhorin'] != null && points['erdene-zuu'] != null) {
              final p = points['kharkhorin']!;
              points['kharkhorin'] = Offset(p.dx, p.dy - 18);
              points['erdene-zuu'] = Offset(p.dx + 8, p.dy + 39);
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SteppeMapPainter(
                      points: points,
                      showRoute: showRoute,
                    ),
                  ),
                ),
                const Positioned(
                  left: 17,
                  top: 16,
                  child: Text(
                    'ORKHON VALLEY',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: OvColors.brown,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                const Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      Icon(
                        Icons.navigation_outlined,
                        size: 25,
                        color: OvColors.green,
                      ),
                      Text(
                        'N',
                        style: TextStyle(fontSize: 10, color: OvColors.green),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: OvColors.cream.withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Illustrated route overview',
                      style: TextStyle(fontSize: 9, color: OvColors.body),
                    ),
                  ),
                ),
                for (final site in sites)
                  Positioned(
                    left: points[site.id]!.dx - 23,
                    top: points[site.id]!.dy - 23,
                    child: Semantics(
                      button: true,
                      selected: selectedSiteId == site.id,
                      label: 'Select ${site.name}',
                      child: GestureDetector(
                        onTap: onSiteTap == null
                            ? null
                            : () => onSiteTap!(site.id),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: selectedSiteId == site.id ? 32 : 25,
                              height: selectedSiteId == site.id ? 32 : 25,
                              decoration: BoxDecoration(
                                color: selectedSiteId == site.id
                                    ? OvColors.gold
                                    : OvColors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: OvColors.cream,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: OvColors.night.withValues(
                                      alpha: .18,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                site.id == 'ulaan-tsutgalan'
                                    ? Icons.water_rounded
                                    : site.id == 'kharkhorin'
                                    ? Icons.castle_outlined
                                    : Icons.temple_buddhist_outlined,
                                size: selectedSiteId == site.id ? 17 : 12,
                                color: selectedSiteId == site.id
                                    ? OvColors.night
                                    : OvColors.cream,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                for (final site in sites)
                  Positioned(
                    left:
                        (points[site.id]!.dx -
                                (site.id == 'tovkhon' ||
                                        site.id == 'ulaan-tsutgalan'
                                    ? 4
                                    : 120))
                            .clamp(8.0, size.width - 130),
                    top:
                        points[site.id]!.dy +
                        (site.id == 'kharkhorin' ? -30 : 19),
                    child: IgnorePointer(
                      child: Text(
                        site.name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: compact ? 9 : 10,
                          color: OvColors.ink,
                          fontWeight: selectedSiteId == site.id
                              ? FontWeight.w600
                              : FontWeight.w500,
                          shadows: const [
                            Shadow(color: OvColors.cream, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SteppeMapPainter extends CustomPainter {
  const _SteppeMapPainter({required this.points, required this.showRoute});
  final Map<String, Offset> points;
  final bool showRoute;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9E7D8),
    );
    final land = Paint()..color = const Color(0xFFD8DEC8);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (.05 + (i % 3) * .39);
      final y = size.height * (.12 + i * .15);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: size.width * .68,
          height: size.height * .24,
        ),
        land,
      );
    }
    final contours = Paint()
      ..color = const Color(0xFF9CA581).withValues(alpha: .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 17; i++) {
      final y = size.height * i / 16;
      final path = Path()
        ..moveTo(-15, y)
        ..cubicTo(
          size.width * .3,
          y - 40,
          size.width * .4,
          y + 46,
          size.width + 15,
          y - 20,
        );
      canvas.drawPath(path, contours);
    }
    final river = Path()
      ..moveTo(size.width * .9, -10)
      ..cubicTo(
        size.width * .64,
        size.height * .25,
        size.width * .88,
        size.height * .36,
        size.width * .54,
        size.height * .55,
      )
      ..cubicTo(
        size.width * .36,
        size.height * .62,
        size.width * .58,
        size.height * .84,
        size.width * .12,
        size.height + 12,
      );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF9BBDC0).withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF84ABAF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final mountainPaint = Paint()
      ..color = const Color(0xFF748663).withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 11; i++) {
      final x = size.width * (.07 + (i % 4) * .11);
      final y = size.height * (.18 + (i ~/ 4) * .18);
      canvas.drawPath(
        Path()
          ..moveTo(x - 7, y + 7)
          ..lineTo(x, y - 7)
          ..lineTo(x + 9, y + 7),
        mountainPaint,
      );
    }
    if (showRoute) {
      final route = [
        'kharkhorin',
        'erdene-zuu',
        'tovkhon',
        'ulaan-tsutgalan',
      ].map((id) => points[id]).whereType<Offset>().toList();
      for (var i = 0; i < route.length - 1; i++) {
        final a = route[i], b = route[i + 1], distance = (b - a).distance;
        for (double t = 0; t < distance; t += 10) {
          canvas.drawLine(
            Offset.lerp(a, b, t / distance)!,
            Offset.lerp(a, b, math.min((t + 5) / distance, 1))!,
            Paint()
              ..color = OvColors.brown.withValues(alpha: .65)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SteppeMapPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.showRoute != showRoute;
}
