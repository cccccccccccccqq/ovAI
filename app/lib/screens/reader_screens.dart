import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../core/audio_controller.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.id});
  final String id;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scroll = ScrollController();
  Timer? _saveTimer;
  StreamSubscription<Duration>? _positionSubscription;
  Future<void> Function(double progress, int positionMs)? _persist;
  bool _restored = false;
  double _progress = 0;
  int _positionMs = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrollChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindReader();
  }

  @override
  void didUpdateWidget(covariant ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    _flushLater();
    _saveTimer?.cancel();
    _saveTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _restored = false;
    _bindReader();
  }

  void _bindReader() {
    final app = AppScope.of(context);
    final storyId = widget.id;
    final story = app.storyById(storyId);
    if (story == null) return;
    final audio = AudioScope.of(context);
    if (!_restored) {
      _restored = true;
      _progress = story.readingProgress;
      _positionMs = story.audioPositionMs;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(
          _scroll.position.maxScrollExtent * _progress.clamp(0, 1),
        );
      });
      _positionSubscription = audio.player.positionStream.listen((position) {
        if (!mounted || audio.currentStoryId != storyId) return;
        _positionMs = position.inMilliseconds;
        _scheduleSave();
      });
    }
    _persist = (progress, positionMs) =>
        app.saveProgress(storyId, progress, positionMs);
  }

  void _flushLater() {
    final persist = _persist;
    final progress = _progress;
    final positionMs = _positionMs;
    if (persist != null) {
      scheduleMicrotask(() => unawaited(persist(progress, positionMs)));
    }
  }

  void _scrollChanged() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _progress = max <= 0 ? 1 : (_scroll.offset / max).clamp(0, 1);
    _scheduleSave();
  }

  void _scheduleSave() {
    // Throttle instead of repeatedly cancelling: playback emits continuously.
    _saveTimer ??= Timer(const Duration(milliseconds: 650), () {
      _saveTimer = null;
      if (mounted && _persist != null) {
        unawaited(_persist!(_progress, _positionMs));
      }
    });
  }

  Future<void> _saveThenGo(String path) async {
    if (_persist != null) await _persist!(_progress, _positionMs);
    if (mounted) context.push(path);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _positionSubscription?.cancel();
    _flushLater();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final story = app.storyById(widget.id);
    if (story == null) return const _MissingStory();
    final template = app.templateFor(story);
    final site = app.siteById(story.siteId);
    return AppScaffold(
      dark: true,
      scroll: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AppImage(
                        path: story.image,
                        height: 252,
                        width: double.infinity,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x660c1f14),
                              Colors.transparent,
                              OvColors.night,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        children: [
                          _ReaderIcon(
                            icon: Icons.close,
                            tooltip: 'Close reader',
                            onTap: () async {
                              if (_persist != null) {
                                await _persist!(_progress, _positionMs);
                              }
                              if (context.mounted) context.go('/scrolls');
                            },
                          ),
                          const Spacer(),
                          _ReaderIcon(
                            icon: story.bookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            tooltip: story.bookmarked
                                ? 'Remove bookmark'
                                : 'Bookmark story',
                            onTap: () => app.toggleStoryBookmark(story.id),
                          ),
                          const SizedBox(width: 8),
                          _ReaderIcon(
                            icon: Icons.ios_share,
                            tooltip: 'Share chronicle',
                            onTap: () => _saveThenGo('/share/${story.id}'),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 2,
                      child: Text(
                        '${site.name.toUpperCase()} · CHAPTER ${template.chapter}',
                        style: const TextStyle(
                          color: OvColors.gold,
                          letterSpacing: 1.5,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  story.title,
                  style: const TextStyle(
                    color: OvColors.cream,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${story.genre} · ${story.style}',
                  style: TextStyle(
                    color: OvColors.cream.withValues(alpha: .65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                const DemoBadge(text: 'Curated demo · original fiction'),
                const SizedBox(height: 26),
                for (final segment in template.segments) ...[
                  if (segment.kind == 'context')
                    _ContextNote(
                      segment: segment,
                      onTap: () => showStorySources(
                        context,
                        template,
                        selectedId: segment.citationId,
                      ),
                    )
                  else
                    SelectableText(
                      segment.text,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.85,
                        fontStyle: FontStyle.italic,
                        color: OvColors.cream.withValues(alpha: .86),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
                OutlinedButton.icon(
                  onPressed: () => showStorySources(context, template),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Reading notes & sources'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OvColors.gold,
                    side: BorderSide(
                      color: OvColors.gold.withValues(alpha: .4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                PillButton(
                  label: template.nextIds.isEmpty
                      ? 'Finish this chapter'
                      : 'Choose your path',
                  icon: Icons.arrow_forward,
                  onPressed: () async {
                    _progress = 1;
                    await _saveThenGo('/reader/${story.id}/end');
                  },
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
          ChronicleAudioPlayer(story: story),
        ],
      ),
    );
  }
}

class ReaderEndScreen extends StatefulWidget {
  const ReaderEndScreen({super.key, required this.id});
  final String id;

  @override
  State<ReaderEndScreen> createState() => _ReaderEndScreenState();
}

class _ReaderEndScreenState extends State<ReaderEndScreen> {
  bool _creating = false;
  String? _error;

  Future<void> _continue(Chronicle parent, StoryTemplate next) async {
    if (_creating) return;
    final app = AppScope.of(context);
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final story = await app.createChronicle(
        templateId: next.id,
        parentId: parent.id,
      );
      if (!mounted) return;
      context.go('/reader/${story.id}');
    } catch (_) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = 'This next chapter could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final story = app.storyById(widget.id);
    if (story == null) return const _MissingStory();
    final template = app.templateFor(story);
    final sources = app.citationsFor(template);
    final paths = template.nextIds.map(app.templateById).toList();
    return AppScaffold(
      dark: true,
      showBack: true,
      title: 'Paths & sources',
      actions: [
        IconButton(
          onPressed: () => context.push('/share/${story.id}'),
          tooltip: 'Share story',
          icon: const Icon(Icons.ios_share, color: OvColors.cream),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHAPTER ${template.chapter} COMPLETE',
            style: const TextStyle(
              fontSize: 11,
              color: OvColors.gold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            story.title,
            style: const TextStyle(
              fontSize: 27,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: OvColors.cream,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            template.segments.where((item) => item.kind == 'legend').last.text,
            style: TextStyle(
              fontSize: 17,
              height: 1.8,
              fontStyle: FontStyle.italic,
              color: OvColors.cream.withValues(alpha: .76),
            ),
          ),
          const SizedBox(height: 26),
          Divider(color: OvColors.cream.withValues(alpha: .16)),
          const SizedBox(height: 22),
          Text(
            paths.isEmpty
                ? 'Every journey leaves a trace.'
                : 'Choose your path',
            style: const TextStyle(
              color: OvColors.cream,
              fontWeight: FontWeight.w600,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            paths.isEmpty
                ? 'Your chapter is in your scrolls. Revisit it any time, or begin a new chronicle.'
                : 'Follow one of the prepared branches. Your choice becomes the next chapter in your journey.',
            style: TextStyle(
              color: OvColors.cream.withValues(alpha: .6),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          for (final path in paths) ...[
            Material(
              color: const Color(0xff162d20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: OvColors.gold.withValues(alpha: .35)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _creating ? null : () => _continue(story, path),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fork_right,
                        color: OvColors.gold,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              path.title,
                              style: const TextStyle(
                                color: OvColors.cream,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              path.seed,
                              style: TextStyle(
                                color: OvColors.cream.withValues(alpha: .65),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_creating)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: OvColors.gold,
                          ),
                        )
                      else
                        const Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: OvColors.gold,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: OvColors.gold),
              ),
            ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: OvColors.green.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DemoBadge(text: 'About this story'),
                const SizedBox(height: 12),
                Text(
                  'This is original writing prepared for the ÖV prototype. Its people, dialogue and events are imagined. The reading notes provide background; they are not exact historical quotations or live AI verification.',
                  style: TextStyle(
                    color: OvColors.cream.withValues(alpha: .8),
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Reading notes',
            style: TextStyle(
              color: OvColors.cream,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final source in sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.menu_book_outlined,
                color: OvColors.gold,
                size: 22,
              ),
              title: Text(
                source.title,
                style: const TextStyle(color: OvColors.cream, fontSize: 14),
              ),
              subtitle: Text(
                source.author,
                style: TextStyle(
                  color: OvColors.cream.withValues(alpha: .55),
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_outward,
                color: OvColors.gold,
                size: 18,
              ),
              onTap: () =>
                  showStorySources(context, template, selectedId: source.id),
            ),
          const SizedBox(height: 22),
          PillButton(
            label: 'View my journey',
            icon: Icons.route_outlined,
            onPressed: () => context.push('/journey/${story.id}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/scrolls'),
            icon: const Icon(Icons.auto_stories_outlined, size: 18),
            label: const Text('Back to my scrolls'),
            style: OutlinedButton.styleFrom(
              foregroundColor: OvColors.cream,
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(color: OvColors.cream.withValues(alpha: .3)),
            ),
          ),
          const SizedBox(height: 24),
          ChronicleAudioPlayer(story: story),
        ],
      ),
    );
  }
}

/// Shared foreground player backed by real local narration files.
class ChronicleAudioPlayer extends StatelessWidget {
  const ChronicleAudioPlayer({super.key, required this.story});
  final Chronicle story;

  String _clock(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final audio = AudioScope.of(context);
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: audio,
      builder: (context, child) => StreamBuilder<PlayerState>(
        stream: audio.player.playerStateStream,
        builder: (context, snapshot) => StreamBuilder<Duration>(
          stream: audio.player.positionStream,
          initialData: audio.player.position,
          builder: (context, positionSnapshot) => StreamBuilder<Duration?>(
            stream: audio.player.durationStream,
            initialData: audio.player.duration,
            builder: (context, durationSnapshot) {
              final active = audio.currentStoryId == story.id;
              final duration = active
                  ? durationSnapshot.data ?? Duration.zero
                  : Duration.zero;
              final position = active
                  ? positionSnapshot.data ?? Duration.zero
                  : Duration(milliseconds: story.audioPositionMs);
              final playing =
                  active &&
                  (snapshot.data?.playing ?? false) &&
                  snapshot.data?.processingState != ProcessingState.completed;
              final loading =
                  active &&
                  (audio.loading ||
                      snapshot.data?.processingState ==
                          ProcessingState.loading ||
                      snapshot.data?.processingState ==
                          ProcessingState.buffering);
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                decoration: BoxDecoration(
                  color: const Color(0xff142c1e),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: OvColors.cream.withValues(alpha: .1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.graphic_eq,
                          color: OvColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                story.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: OvColors.cream,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${app.voiceById(story.voiceId).name} · recorded demo',
                                style: TextStyle(
                                  color: OvColors.cream.withValues(alpha: .55),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<double>(
                          tooltip: 'Narration speed',
                          color: const Color(0xff243d2c),
                          initialValue: audio.player.speed,
                          onSelected: (speed) async {
                            await audio.setSpeed(speed);
                          },
                          itemBuilder: (context) => [
                            for (final speed in [.75, 1.0, 1.25, 1.5, 2.0])
                              PopupMenuItem(
                                value: speed,
                                child: Text(
                                  '$speed×',
                                  style: const TextStyle(color: OvColors.cream),
                                ),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              '${audio.player.speed}×',
                              style: const TextStyle(
                                color: OvColors.gold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(
                          0,
                          duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1,
                        ),
                        max: duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1,
                        activeColor: OvColors.gold,
                        inactiveColor: OvColors.cream.withValues(alpha: .2),
                        onChanged: active && duration > Duration.zero
                            ? (value) => audio.seek(
                                Duration(milliseconds: value.round()),
                              )
                            : null,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _clock(position),
                          style: TextStyle(
                            color: OvColors.cream.withValues(alpha: .6),
                            fontSize: 11,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Back 10 seconds',
                              onPressed: active && !loading
                                  ? () => audio.seek(
                                      Duration(
                                        milliseconds:
                                            (position.inMilliseconds - 10000)
                                                .clamp(
                                                  0,
                                                  duration.inMilliseconds,
                                                ),
                                      ),
                                    )
                                  : null,
                              icon: Icon(
                                Icons.replay_10,
                                color: active ? OvColors.cream : OvColors.body,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: Semantics(
                                label: loading
                                    ? 'Loading narration'
                                    : (playing
                                          ? 'Pause narration'
                                          : 'Play narration'),
                                button: true,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                    backgroundColor: OvColors.gold,
                                    foregroundColor: OvColors.night,
                                  ),
                                  onPressed: loading
                                      ? null
                                      : () async {
                                          if (!active || audio.error != null) {
                                            await audio.playStory(story);
                                          } else {
                                            await audio.toggle();
                                          }
                                        },
                                  child: loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: OvColors.gold,
                                          ),
                                        )
                                      : Icon(
                                          playing
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          size: 27,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Forward 10 seconds',
                              onPressed: active && !loading
                                  ? () => audio.seek(
                                      Duration(
                                        milliseconds:
                                            (position.inMilliseconds + 10000)
                                                .clamp(
                                                  0,
                                                  duration.inMilliseconds,
                                                ),
                                      ),
                                    )
                                  : null,
                              icon: Icon(
                                Icons.forward_10,
                                color: active ? OvColors.cream : OvColors.body,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          duration == Duration.zero
                              ? '--:--'
                              : _clock(duration),
                          style: TextStyle(
                            color: OvColors.cream.withValues(alpha: .6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (active && audio.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        audio.error!,
                        style: const TextStyle(
                          color: OvColors.gold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => audio.playStory(story),
                        child: const Text(
                          'Retry narration',
                          style: TextStyle(color: OvColors.gold),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> showStorySources(
  BuildContext context,
  StoryTemplate template, {
  String? selectedId,
}) async {
  final app = AppScope.of(context);
  final sources = app.citationsFor(template).toList();
  sources.sort(
    (a, b) =>
        (a.id == selectedId ? 0 : 1).compareTo(b.id == selectedId ? 0 : 1),
  );
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: OvColors.cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reading notes & sources',
                style: TextStyle(
                  color: OvColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Prepared editorial context for a fictional demo story. These notes are not exact historical quotes, and no live verification was performed.',
                style: TextStyle(
                  color: OvColors.body,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              for (final source in sources) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: source.id == selectedId
                          ? OvColors.green
                          : const Color(0xffd8d6cc),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        style: const TextStyle(
                          color: OvColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${source.author}\n${source.page}',
                        style: const TextStyle(
                          color: OvColors.brown,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        source.note,
                        style: const TextStyle(
                          color: OvColors.body,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      if (source.url != null) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(
                              sheetContext,
                            );
                            try {
                              final opened = await launchUrl(
                                Uri.parse(source.url!),
                                mode: LaunchMode.externalApplication,
                              );
                              if (!opened && sheetContext.mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This device could not open the source link.',
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (sheetContext.mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'The source link is unavailable on this device.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open source'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ContextNote extends StatelessWidget {
  const _ContextNote({required this.segment, required this.onTap});
  final StorySegment segment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff1d3425),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xff738b53)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 20,
              color: Color(0xffa3b56b),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTEXT · READING NOTE',
                    style: TextStyle(
                      color: Color(0xffa3b56b),
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    segment.text,
                    style: TextStyle(
                      color: OvColors.cream.withValues(alpha: .85),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Color(0xffa3b56b), size: 17),
          ],
        ),
      ),
    ),
  );
}

class _ReaderIcon extends StatelessWidget {
  const _ReaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: OvColors.night.withValues(alpha: .65),
    shape: const CircleBorder(),
    child: IconButton(
      icon: Icon(icon, color: OvColors.cream, size: 21),
      tooltip: tooltip,
      onPressed: onTap,
    ),
  );
}

class _MissingStory extends StatelessWidget {
  const _MissingStory();
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Chronicle unavailable',
    showBack: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This local chronicle was removed or is not saved on this device.',
        ),
        const SizedBox(height: 24),
        PillButton(
          label: 'Open my scrolls',
          onPressed: () => context.go('/scrolls'),
        ),
      ],
    ),
  );
}
