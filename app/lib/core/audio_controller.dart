import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import 'app_state.dart';
import 'models.dart';

/// One real player shared by Reader, voice previews and journey playback.
class AudioController extends ChangeNotifier {
  AudioController(this.state) {
    _subscriptions.add(
      player.positionStream.listen((position) {
        final id = currentStoryId;
        if (_disposed || id == null || loading) return;
        if ((position.inMilliseconds - _lastSaved).abs() > 1800) {
          _lastSaved = position.inMilliseconds;
          final story = state.storyById(id);
          if (story != null) {
            unawaited(_savePosition(story, _lastSaved));
          }
        }
      }),
    );
    _subscriptions.add(
      player.errorStream.listen((event) {
        if (_disposed || (currentStoryId == null && previewVoiceId == null)) {
          return;
        }
        error = 'The recording could not be played. Please try again.';
        loading = false;
        _emit();
      }),
    );
  }

  final AppState state;
  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? currentStoryId;
  String? previewVoiceId;
  bool loading = false;
  String? error;
  int _request = 0;
  int _lastSaved = 0;
  bool _disposed = false;

  bool _active(int request) => !_disposed && request == _request;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _savePosition(Chronicle story, int positionMs) async {
    if (_disposed) return;
    try {
      await state.saveProgress(story.id, story.readingProgress, positionMs);
    } catch (_) {
      // Local storage can fail independently of playback. A failed progress
      // write must not prevent stopping or opening the next recording.
    }
  }

  Future<void> _remember() async {
    if (_disposed) return;
    final id = currentStoryId;
    final story = id == null ? null : state.storyById(id);
    if (story != null) {
      await _savePosition(story, player.position.inMilliseconds);
    }
  }

  void _startPlayback(int request, String failureMessage) {
    if (!_active(request)) return;
    unawaited(
      player.play().catchError((Object _) {
        if (!_active(request)) return;
        error = failureMessage;
        loading = false;
        _emit();
      }),
    );
  }

  Future<void> playStory(Chronicle story, {bool autoplay = true}) async {
    if (_disposed) return;
    final request = ++_request;
    if (currentStoryId == story.id && !loading && error == null) {
      if (!autoplay) return;
      try {
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
          if (!_active(request)) return;
        }
        _startPlayback(request, 'Tap play to try this recording again.');
      } catch (_) {
        if (!_active(request)) return;
        error = 'Unable to restart the recording. Please try again.';
        loading = false;
        _emit();
      }
      return;
    }
    await _remember();
    if (!_active(request)) return;
    currentStoryId = story.id;
    previewVoiceId = null;
    error = null;
    loading = true;
    _emit();
    try {
      await player.stop();
      if (!_active(request)) return;
      final duration = await player.setAudioSource(
        AudioSource.asset(state.audioAssetFor(story)),
        initialPosition: Duration(milliseconds: story.audioPositionMs),
      );
      if (!_active(request)) return;
      if (duration != null && player.position >= duration) {
        await player.seek(Duration.zero);
        if (!_active(request)) return;
      }
      await player.setSpeed(state.playbackSpeed);
      if (!_active(request)) return;
      _lastSaved = player.position.inMilliseconds;
      loading = false;
      error = null;
      _emit();
      if (autoplay) {
        _startPlayback(request, 'Tap play to start this recording.');
      }
    } catch (_) {
      if (!_active(request)) return;
      loading = false;
      error = 'Unable to load the demo recording. Try again.';
      _emit();
    }
  }

  Future<void> previewVoice(String voiceId) async {
    if (_disposed) return;
    final request = ++_request;
    await _remember();
    if (!_active(request)) return;
    currentStoryId = null;
    previewVoiceId = voiceId;
    loading = true;
    error = null;
    _emit();
    try {
      await player.stop();
      if (!_active(request)) return;
      await player.setAsset('assets/audio/$voiceId/preview.m4a');
      if (!_active(request)) return;
      await player.setSpeed(1);
      if (!_active(request)) return;
      loading = false;
      error = null;
      _emit();
      _startPlayback(request, 'Preview is unavailable. Try again.');
    } catch (_) {
      if (!_active(request)) return;
      loading = false;
      error = 'Preview is unavailable. Try again.';
      _emit();
    }
  }

  Future<void> toggle() async {
    if (_disposed || loading) return;
    if (currentStoryId == null && previewVoiceId == null) return;
    final request = ++_request;
    try {
      // just_audio can remain playing=true at the end of a recording. Treat
      // completed as replay before considering the ordinary pause branch.
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
        if (!_active(request)) return;
        error = null;
        _emit();
        _startPlayback(request, 'Audio playback failed. Try again.');
      } else if (player.playing) {
        await player.pause();
        if (!_active(request)) return;
        await _remember();
        if (!_active(request)) return;
        error = null;
        _emit();
      } else {
        error = null;
        _emit();
        _startPlayback(request, 'Audio playback failed. Try again.');
      }
    } catch (_) {
      if (!_active(request)) return;
      error = 'Audio playback failed. Try again.';
      loading = false;
      _emit();
    }
  }

  Future<void> seek(Duration position) async {
    if (_disposed || loading) return;
    final request = _request;
    try {
      final max = player.duration ?? position;
      await player.seek(
        Duration(
          milliseconds: position.inMilliseconds.clamp(0, max.inMilliseconds),
        ),
      );
      if (!_active(request)) return;
      await _remember();
    } catch (_) {
      if (!_active(request)) return;
      error = 'Unable to move within this recording. Try again.';
      _emit();
    }
  }

  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    final request = _request;
    try {
      await state.setPlaybackSpeed(speed);
      if (!_active(request)) return;
      await player.setSpeed(state.playbackSpeed);
      if (!_active(request)) return;
      _emit();
    } catch (_) {
      if (!_active(request)) return;
      error = 'Unable to change narration speed. Try again.';
      _emit();
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    final request = ++_request;
    await _remember();
    if (!_active(request)) return;
    try {
      await player.stop();
      if (!_active(request)) return;
      loading = false;
      error = null;
      currentStoryId = null;
      previewVoiceId = null;
      _emit();
    } catch (_) {
      if (!_active(request)) return;
      loading = false;
      error = 'The recording could not be stopped. Try again.';
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(player.dispose().catchError((Object _) {}));
    super.dispose();
  }
}

class AudioScope extends InheritedNotifier<AudioController> {
  const AudioScope({
    super.key,
    required AudioController controller,
    required super.child,
  }) : super(notifier: controller);

  static AudioController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AudioScope>()!.notifier!;
}
