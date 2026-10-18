/// Published research chapters are shared content; listening progress is private.
class HistoricalChapter {
  const HistoricalChapter({
    required this.id,
    required this.title,
    required this.seriesId,
    required this.contentVersion,
    required this.durationMs,
    required this.narration,
    required this.audioPath,
    required this.sourceSections,
    required this.scenes,
  });

  factory HistoricalChapter.fromDocument(String id, Map<String, dynamic> data) {
    if (data['status'] != 'published' || data['language'] != 'mn') {
      throw const FormatException('Published Mongolian chapter required.');
    }
    final audio = data['audio'] as Map<String, dynamic>?;
    final duration = (data['durationMs'] as num?)?.toInt() ?? 0;
    final version = (data['contentVersion'] as num?)?.toInt() ?? 0;
    final narration = (data['narration'] ?? data['narrationText']) as String?;
    final path = (audio?['storagePath'] ?? data['audioPath']) as String?;
    if (duration <= 0 || version <= 0 || narration == null || path == null) {
      throw const FormatException('Chapter content or audio is incomplete.');
    }
    final scenes =
        (data['scenes'] as List<dynamic>? ?? [])
            .map(
              (value) => HistoricalScene.fromMap(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.startMs.compareTo(b.startMs));
    for (final scene in scenes) {
      if (scene.startMs < 0 ||
          scene.endMs <= scene.startMs ||
          scene.endMs > duration) {
        throw const FormatException(
          'Scene timestamps are outside the chapter.',
        );
      }
    }
    return HistoricalChapter(
      id: id,
      title: data['title'] as String,
      seriesId: data['seriesId'] as String,
      contentVersion: version,
      durationMs: duration,
      narration: narration,
      audioPath: path,
      sourceSections: List<int>.from(data['sourceSections'] as List),
      scenes: List.unmodifiable(scenes),
    );
  }

  final String id;
  final String title;
  final String seriesId;
  final int contentVersion;
  final int durationMs;
  final String narration;
  final String audioPath;
  final List<int> sourceSections;
  final List<HistoricalScene> scenes;

  HistoricalScene? sceneAt(int positionMs) {
    for (final scene in scenes.reversed) {
      if (positionMs >= scene.startMs && positionMs < scene.endMs) return scene;
    }
    return positionMs >= durationMs ? scenes.lastOrNull : null;
  }
}

class HistoricalScene {
  const HistoricalScene({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.placeId,
    required this.caption,
  });
  factory HistoricalScene.fromMap(Map<String, dynamic> data) => HistoricalScene(
    id: data['id'] as String,
    startMs: (data['startMs'] as num).toInt(),
    endMs: (data['endMs'] as num).toInt(),
    placeId: data['placeId'] as String,
    caption: data['caption'] as String,
  );
  final String id;
  final int startMs;
  final int endMs;
  final String placeId;
  final String caption;
}

class HistoricalPlace {
  const HistoricalPlace({
    required this.id,
    required this.name,
    required this.modernName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.confidence,
    required this.description,
  });
  factory HistoricalPlace.fromDocument(String id, Map<String, dynamic> data) {
    final center = data['center'] as Map<String, dynamic>?;
    final lat = ((center?['latitude'] ?? data['latitude']) as num).toDouble();
    final lng = ((center?['longitude'] ?? data['longitude']) as num).toDouble();
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
      throw const FormatException('Invalid place region.');
    }
    return HistoricalPlace(
      id: id,
      name: data['historicalName'] as String,
      modernName: (data['modernName'] ?? data['currentName'] ?? '') as String,
      latitude: lat,
      longitude: lng,
      radiusMeters:
          (data['radiusMeters'] as num?)?.toDouble() ??
          ((data['radiusKm'] as num?)?.toDouble() ?? 50) * 1000,
      confidence: data['confidence'] as String? ?? 'uncertain',
      description:
          (data['description'] ?? data['locationNote'] ?? '') as String,
    );
  }
  final String id;
  final String name;
  final String modernName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String confidence;
  final String description;
  double get overviewZoom => radiusMeters > 100000 ? 6.5 : 7.5;
}

class ChapterProgress {
  const ChapterProgress({
    required this.contentVersion,
    this.audioPositionMs = 0,
    this.bookmarked = false,
    this.completed = false,
  });
  factory ChapterProgress.fromMap(Map<String, dynamic> data) => ChapterProgress(
    contentVersion: (data['contentVersion'] as num?)?.toInt() ?? 0,
    audioPositionMs: (data['audioPositionMs'] as num?)?.toInt() ?? 0,
    bookmarked: data['bookmarked'] == true,
    completed: data['completed'] == true,
  );
  final int contentVersion;
  final int audioPositionMs;
  final bool bookmarked;
  final bool completed;

  /// Old timestamps must not be applied to a newly edited narration.
  ChapterProgress forChapter(HistoricalChapter chapter) =>
      contentVersion == chapter.contentVersion
      ? ChapterProgress(
          contentVersion: contentVersion,
          audioPositionMs: audioPositionMs.clamp(0, chapter.durationMs),
          bookmarked: bookmarked,
          completed: completed,
        )
      : ChapterProgress(
          contentVersion: chapter.contentVersion,
          bookmarked: bookmarked,
        );
}

class ChapterBundle {
  const ChapterBundle({
    required this.chapter,
    required this.places,
    required this.progress,
    required this.uid,
  });
  final HistoricalChapter chapter;
  final Map<String, HistoricalPlace> places;
  final ChapterProgress progress;
  final String uid;
}
