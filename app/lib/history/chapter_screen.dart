import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:go_router/go_router.dart';
import '../core/audio_controller.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'chapter_map.dart';
import 'chapter_models.dart';
import 'chapter_repository.dart';

class HistoricalChapterScreen extends StatefulWidget {
  const HistoricalChapterScreen({super.key, required this.chapterId});
  final String chapterId;
  @override
  State<HistoricalChapterScreen> createState() =>
      _HistoricalChapterScreenState();
}

class _HistoricalChapterScreenState extends State<HistoricalChapterScreen>
    with WidgetsBindingObserver {
  final _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  ChapterRepository? _repository;
  ChapterBundle? _bundle;
  String? _error;
  String? _audioError;
  String _saveStatus = 'Сонссон хугацаа автоматаар хадгалагдана';
  bool _loading = true;
  bool _audioReady = false;
  bool _bookmarked = false;
  bool _completed = false;
  bool _follow = true;
  bool _saving = false;
  bool _savePending = false;
  Completer<void>? _saveCompletion;
  bool _closing = false;
  bool _disposed = false;
  int _positionMs = 0;
  int _lastSaveSecond = 0;
  double? _dragPosition;

  HistoricalChapter get _chapter => _bundle!.chapter;
  HistoricalScene? get _scene => _bundle?.chapter.sceneAt(_positionMs);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscriptions.add(
      _player.positionStream.listen((position) {
        if (!mounted || !_audioReady) return;
        setState(
          () => _positionMs = position.inMilliseconds.clamp(
            0,
            _chapter.durationMs,
          ),
        );
        final second = _positionMs ~/ 1000;
        if (_player.playing && (second - _lastSaveSecond).abs() >= 10) {
          _lastSaveSecond = second;
          unawaited(_save());
        }
      }),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (!mounted || _disposed) return;
        setState(() {});
        if (state.processingState == ProcessingState.completed &&
            _bundle != null &&
            _audioReady) {
          _positionMs = _chapter.durationMs;
          _completed = true;
          unawaited(_save());
        }
      }),
    );
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object _) {
          if (mounted && !_disposed) {
            setState(
              () => _audioError =
                  'Аудио тоглуулахад алдаа гарлаа. Дахин ачаална уу.',
            );
          }
        },
      ),
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = await ChapterRepository.connect();
      final bundle = await repository.load(widget.chapterId);
      if (!mounted || _disposed) return;
      _repository = repository;
      setState(() {
        _bundle = bundle;
        _positionMs = bundle.progress.audioPositionMs;
        _lastSaveSecond = _positionMs ~/ 1000;
        _bookmarked = bundle.progress.bookmarked;
        _completed = bundle.progress.completed;
        _loading = false;
        _saveStatus = bundle.progress.audioPositionMs > 0
            ? '${_time(_positionMs)}-ээс үргэлжлүүлэхэд бэлэн · Firestore'
            : 'Firestore-оос chapter ачааллаа';
      });
      await _loadAudio();
    } catch (error, stack) {
      debugPrint('Historical chapter load failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted && !_disposed) {
        setState(() {
          _loading = false;
          _error =
              'Local backend-тэй холбогдож чадсангүй. Firebase emulator болон chapter-ийн өгөгдөл бэлэн эсэхийг шалгана уу.';
        });
      }
    }
  }

  Future<void> _loadAudio() async {
    setState(() {
      _audioReady = false;
      _audioError = null;
    });
    try {
      final url = await _repository!.audioUrl(_chapter);
      await _player.setUrl(url).timeout(const Duration(seconds: 20));
      await _player.seek(Duration(milliseconds: _positionMs));
      if (mounted && !_disposed) setState(() => _audioReady = true);
    } catch (_) {
      if (mounted && !_disposed) {
        setState(
          () => _audioError =
              'Storage дахь монгол аудиог ачаалж чадсангүй. Өгүүлэмж болон газрын зураг үзэх боломжтой.',
        );
      }
    }
  }

  Future<void> _togglePlay() async {
    if (!_audioReady) return;
    await AudioScope.of(context).stop();
    try {
      if (_player.playing) {
        await _player.pause();
        await _save();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _seek(0);
          _completed = false;
        }
        unawaited(
          _player.play().catchError((Object _) {
            if (mounted && !_disposed) {
              setState(
                () => _audioError =
                    'Аудио тоглуулах боломжгүй байна. Дахин ачаална уу.',
              );
            }
          }),
        );
      }
    } catch (_) {
      if (mounted && !_disposed) {
        setState(() => _audioError = 'Аудио тоглуулах боломжгүй байна.');
      }
    }
  }

  Future<void> _seek(int milliseconds) async {
    if (!_audioReady) return;
    final position = milliseconds.clamp(0, _chapter.durationMs);
    await _player.seek(Duration(milliseconds: position));
    if (!mounted || _disposed) return;
    setState(() {
      _positionMs = position;
      _dragPosition = null;
    });
    _lastSaveSecond = position ~/ 1000;
    await _save();
  }

  /// Serialize snapshots so an older in-flight request cannot overwrite a seek.
  Future<void> _save() {
    if (_repository == null || _bundle == null) return Future.value();
    _savePending = true;
    if (_saveCompletion != null) return _saveCompletion!.future;
    final completion = Completer<void>();
    _saveCompletion = completion;
    unawaited(_drainSaves(completion));
    return completion.future;
  }

  Future<void> _drainSaves(Completer<void> completion) async {
    _saving = true;
    try {
      while (_savePending) {
        _savePending = false;
        final position = _positionMs;
        if (mounted && !_disposed) {
          setState(() => _saveStatus = 'Firestore-д хадгалж байна…');
        }
        try {
          await _repository!.save(
            _chapter,
            audioPositionMs: position,
            bookmarked: _bookmarked,
            completed: _completed,
          );
          if (mounted && !_disposed) {
            setState(
              () => _saveStatus = '${_time(position)} · Firestore-д хадгаллаа',
            );
          }
        } catch (_) {
          if (mounted && !_disposed) {
            setState(
              () => _saveStatus = 'Хадгалж чадсангүй · Дахин хадгалах дарна уу',
            );
          }
        }
      }
    } finally {
      _saving = false;
      _saveCompletion = null;
      completion.complete();
      if (mounted && !_disposed) setState(() {});
    }
  }

  Future<void> _leave() async {
    if (_closing) return;
    _closing = true;
    await _player.pause();
    await _save();
    if (!mounted || _disposed) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/steppe');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_player.pause());
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_save());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  static String _time(int ms) =>
      '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        eyebrow: 'Монголын нууц товчоо',
        title: 'Түүхээ нээж байна',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_error != null) {
      return AppScaffold(
        eyebrow: 'Local Firebase',
        title: 'Холболт шалгах',
        child: Column(
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Дахин оролдох')),
          ],
        ),
      );
    }
    final chapter = _chapter;
    final scene = _scene;
    final place = _bundle!.places[scene?.placeId];
    return PopScope(
      canPop: true,
      child: AppScaffold(
        showBack: false,
        eyebrow: 'Монголын нууц товчоо · Chapter 1',
        title: chapter.title,
        actions: [
          IconButton(
            tooltip: 'Хаах',
            onPressed: _leave,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const DemoBadge(text: 'LOCAL FIREBASE'),
                DemoBadge(text: '${_time(chapter.durationMs)} АУДИО'),
                DemoBadge(
                  text:
                      '§${chapter.sourceSections.first}–${chapter.sourceSections.last}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Туршилтын local бүртгэл · ${_bundle!.uid.substring(0, 8)}\nТүүхийг Firestore-оос, аудиог Storage emulator-оос ачаалж байна.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: OvColors.night,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ононы эрэг рүү сонсох аялал',
                    style: TextStyle(
                      color: OvColors.cream,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        tooltip: '15 секунд ухрах',
                        onPressed: _audioReady
                            ? () => _seek(_positionMs - 15000)
                            : null,
                        icon: const Icon(
                          Icons.replay_rounded,
                          color: OvColors.cream,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        tooltip: _player.playing ? 'Түр зогсоох' : 'Сонсох',
                        style: IconButton.styleFrom(
                          backgroundColor: OvColors.gold,
                          foregroundColor: OvColors.night,
                          fixedSize: const Size(64, 64),
                        ),
                        onPressed: _audioReady && _audioError == null
                            ? _togglePlay
                            : null,
                        icon: !_audioReady && _audioError == null
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _player.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 34,
                              ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '15 секунд урагшлах',
                        onPressed: _audioReady
                            ? () => _seek(_positionMs + 15000)
                            : null,
                        icon: const Icon(
                          Icons.forward_rounded,
                          color: OvColors.cream,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: (_dragPosition ?? _positionMs.toDouble()).clamp(
                      0.0,
                      chapter.durationMs.toDouble(),
                    ),
                    max: chapter.durationMs.toDouble(),
                    onChanged: _audioReady
                        ? (value) => setState(() => _dragPosition = value)
                        : null,
                    onChangeEnd: (value) => _seek(value.toInt()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _time((_dragPosition ?? _positionMs).toInt()),
                        style: const TextStyle(color: OvColors.cream),
                      ),
                      Text(
                        _time(chapter.durationMs),
                        style: const TextStyle(color: OvColors.cream),
                      ),
                    ],
                  ),
                  if (_audioError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _audioError!,
                      style: const TextStyle(
                        color: OvColors.cream,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadAudio,
                      child: const Text(
                        'Аудиог дахин ачаалах',
                        style: TextStyle(color: OvColors.gold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _saveStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Дахин хадгалах',
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.cloud_done_outlined),
                ),
                IconButton(
                  tooltip: 'Bookmark',
                  onPressed: () {
                    setState(() => _bookmarked = !_bookmarked);
                    unawaited(_save());
                  },
                  icon: Icon(
                    _bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: OvColors.brown,
                  ),
                ),
              ],
            ),
            if (_completed)
              const Text(
                '✓ Chapter-ийг сонсож дууссан',
                style: TextStyle(color: OvColors.green),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 310,
              child: ChapterMap(
                places: _bundle!.places,
                selectedPlaceId: scene?.placeId,
                follow: _follow,
                onUserPan: () {
                  if (_follow && mounted) setState(() => _follow = false);
                },
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Өгүүлэмжийн газрыг дагах'),
              subtitle: const Text('Map-аа чөлөөтэй үзэхэд аудио үргэлжилнэ.'),
              value: _follow,
              onChanged: (value) => setState(() => _follow = value),
            ),
            if (scene != null)
              Text(
                scene.caption,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (place != null) ...[
              const SizedBox(height: 7),
              Text(
                '${place.name} · ${place.modernName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                place.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: chapter.scenes
                  .map(
                    (item) => ActionChip(
                      label: Text(
                        '${_time(item.startMs)} · ${item.caption}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: _audioReady ? () => _seek(item.startMs) : null,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 22),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Өгүүлэмжийг унших'),
              children: [
                SelectableText(
                  chapter.narration,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const Divider(),
            Text(
              'Эхийн хэсэг: Монголын нууц товчоо §${chapter.sourceSections.first}–${chapter.sourceSections.last}.\nЭнэ нь prototype-ийн шинэчилсэн товч өгүүлэмж. Газрын тойргууд нь судалгааны ерөнхий бүс; түүхэн аяллын яг замыг дүрслээгүй.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
