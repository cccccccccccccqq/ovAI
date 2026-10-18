import '../history/chapter_models.dart';

/// Curated content and local records for the öv AI interactive prototype.
/// Historical passages are editorial demo material, not generated research.
class Site {
  const Site({
    required this.id,
    required this.name,
    required this.nameMn,
    required this.summary,
    required this.lat,
    required this.lng,
    required this.image,
    required this.era,
    this.locationNote,
    this.radiusMeters,
  });

  final String id;
  final String name;
  final String nameMn;
  final String summary;
  final double lat;
  final double lng;
  final String image;
  final String era;
  final String? locationNote;
  final double? radiusMeters;
  bool get isApproximate => locationNote != null;

  factory Site.fromJson(Map<String, dynamic> data) => Site(
    id: data['id'] as String,
    name: data['name'] as String,
    nameMn: data['nameMn'] as String? ?? '',
    summary: data['summary'] as String,
    lat: (data['lat'] as num).toDouble(),
    lng: (data['lng'] as num).toDouble(),
    image:
        (data['image'] ??
                (data['imagePath'] as String?)?.replaceFirst(
                  'catalog/',
                  'assets/',
                ))
            as String,
    era: data['era'] as String,
    locationNote: (data['locationNote'] ?? data['mapNotice']) as String?,
    radiusMeters:
        (data['radiusMeters'] as num?)?.toDouble() ??
        (data['locationConfidence'] == 'regional' ? 20000 : null),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameMn': nameMn,
    'summary': summary,
    'lat': lat,
    'lng': lng,
    'image': image,
    'era': era,
    if (locationNote != null) 'locationNote': locationNote,
    if (radiusMeters != null) 'radiusMeters': radiusMeters,
  };
}

class DemoVoice {
  const DemoVoice({
    required this.id,
    required this.name,
    required this.description,
    required this.systemVoice,
  });

  final String id;
  final String name;
  final String description;
  final String systemVoice;
}

class StorySegment {
  const StorySegment({required this.text, required this.kind, this.citationId});

  final String text;

  /// `legend` is original fiction; `context` is a curated editorial note.
  final String kind;
  final String? citationId;
}

class Citation {
  const Citation({
    required this.id,
    required this.title,
    required this.author,
    required this.page,
    required this.note,
    this.url,
  });

  final String id;
  final String title;
  final String author;
  final String page;
  final String note;
  final String? url;
}

class StoryTemplate {
  const StoryTemplate({
    required this.id,
    required this.siteId,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.chapter,
    required this.genre,
    required this.style,
    required this.mood,
    required this.seed,
    required this.segments,
    this.nextIds = const [],
    this.contentKind = 'prepared-demo',
    this.contentVersion = 1,
    this.language = 'en',
    this.durationMs,
    this.seriesId,
    this.sourceSections = const [],
    this.historicalScenes = const [],
    this.citations = const [],
    this.audioByVoice = const {},
  });

  final String id;
  final String siteId;
  final String title;
  final String subtitle;
  final String image;
  final int chapter;
  final String genre;
  final String style;
  final String mood;
  final String seed;
  final List<StorySegment> segments;
  final List<String> nextIds;
  final String contentKind;
  final int contentVersion;
  final String language;
  final int? durationMs;
  final String? seriesId;
  final List<int> sourceSections;
  final List<HistoricalScene> historicalScenes;
  final List<Citation> citations;
  final Map<String, String> audioByVoice;
  bool get isHistorical => contentKind == 'historical-synopsis';

  factory StoryTemplate.fromJson(Map<String, dynamic> data) => StoryTemplate(
    id: (data['id'] ?? data['templateId']) as String,
    siteId: data['siteId'] as String,
    title: data['title'] as String,
    subtitle: data['subtitle'] as String,
    image:
        (data['image'] ??
                (data['imagePath'] as String?)?.replaceFirst(
                  'catalog/',
                  'assets/',
                ) ??
                'assets/images/steppe.jpg')
            as String,
    chapter: (data['chapter'] as num).toInt(),
    genre: data['genre'] as String,
    style: data['style'] as String,
    mood: data['mood'] as String,
    seed: data['seed'] as String,
    segments: (data['segments'] as List).map((v) {
      final value = Map<String, dynamic>.from(v as Map);
      return StorySegment(
        text: value['text'] as String,
        kind: value['kind'] as String,
        citationId: value['citationId'] as String?,
      );
    }).toList(),
    nextIds: List<String>.from(data['nextIds'] as List? ?? []),
    contentKind: data['contentKind'] as String? ?? 'prepared-demo',
    contentVersion: (data['contentVersion'] as num?)?.toInt() ?? 1,
    language: data['language'] as String? ?? 'en',
    durationMs: (data['durationMs'] as num?)?.toInt(),
    seriesId: data['seriesId'] as String?,
    sourceSections: List<int>.from(data['sourceSections'] as List? ?? []),
    historicalScenes: (data['scenes'] as List? ?? [])
        .map(
          (v) => HistoricalScene.fromMap(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
    citations: (data['citations'] as List? ?? []).map((v) {
      final value = Map<String, dynamic>.from(v as Map);
      return Citation(
        id: value['id'] as String,
        title: value['title'] as String,
        author: value['author'] as String,
        page: value['page'] as String,
        note: value['note'] as String,
        url: value['url'] as String?,
      );
    }).toList(),
    audioByVoice: (data['audioByVoice'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(
        key,
        value is String ? value : (value as Map)['storagePath'] as String,
      ),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'siteId': siteId,
    'title': title,
    'subtitle': subtitle,
    'image': image,
    'chapter': chapter,
    'genre': genre,
    'style': style,
    'mood': mood,
    'seed': seed,
    'segments': segments
        .map(
          (s) => {
            'text': s.text,
            'kind': s.kind,
            if (s.citationId != null) 'citationId': s.citationId,
          },
        )
        .toList(),
    'nextIds': nextIds,
    'contentKind': contentKind,
    'contentVersion': contentVersion,
    'language': language,
    if (durationMs != null) 'durationMs': durationMs,
    if (seriesId != null) 'seriesId': seriesId,
    'sourceSections': sourceSections,
    'scenes': historicalScenes
        .map(
          (s) => {
            'id': s.id,
            'startMs': s.startMs,
            'endMs': s.endMs,
            'placeId': s.placeId,
            'caption': s.caption,
          },
        )
        .toList(),
    'citations': citations
        .map(
          (s) => {
            'id': s.id,
            'title': s.title,
            'author': s.author,
            'page': s.page,
            'note': s.note,
            if (s.url != null) 'url': s.url,
          },
        )
        .toList(),
    'audioByVoice': audioByVoice,
  };

  String get plainText => segments.map((segment) => segment.text).join('\n\n');
  int get readingMinutes => (plainText.split(RegExp(r'\s+')).length / 180)
      .ceil()
      .clamp(1, 60)
      .toInt();
  bool get isDemo => !isHistorical;
}

class ChronicleDraft {
  const ChronicleDraft({
    required this.id,
    required this.siteId,
    required this.genre,
    required this.style,
    required this.mood,
    required this.seed,
    required this.voiceId,
    this.coverPath,
  });

  final String id;
  final String siteId;
  final String genre;
  final String style;
  final String mood;
  final String seed;
  final String voiceId;
  final String? coverPath;

  ChronicleDraft copyWith({
    String? id,
    String? siteId,
    String? genre,
    String? style,
    String? mood,
    String? seed,
    String? voiceId,
    String? coverPath,
    bool clearCover = false,
  }) => ChronicleDraft(
    id: id ?? this.id,
    siteId: siteId ?? this.siteId,
    genre: genre ?? this.genre,
    style: style ?? this.style,
    mood: mood ?? this.mood,
    seed: seed ?? this.seed,
    voiceId: voiceId ?? this.voiceId,
    coverPath: clearCover ? null : coverPath ?? this.coverPath,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'siteId': siteId,
    'genre': genre,
    'style': style,
    'mood': mood,
    'seed': seed,
    'voiceId': voiceId,
    'coverPath': coverPath,
  };

  factory ChronicleDraft.fromJson(Map<String, dynamic> json) => ChronicleDraft(
    id: json['id'] as String,
    siteId: json['siteId'] as String,
    genre: json['genre'] as String,
    style: json['style'] as String,
    mood: json['mood'] as String,
    seed: json['seed'] as String,
    voiceId: json['voiceId'] as String,
    coverPath: json['coverPath'] as String?,
  );
}

class Chronicle {
  const Chronicle({
    required this.id,
    required this.templateId,
    required this.siteId,
    required this.title,
    required this.voiceId,
    required this.genre,
    required this.style,
    required this.mood,
    required this.seed,
    required this.image,
    required this.createdAt,
    this.parentId,
    this.bookmarked = false,
    this.readingProgress = 0,
    this.audioPositionMs = 0,
    this.remoteUid,
    this.contentVersion = 1,
  });

  final String id;
  final String templateId;
  final String siteId;
  final String title;
  final String voiceId;
  final String genre;
  final String style;
  final String mood;
  final String seed;
  final String image;
  final DateTime createdAt;
  final String? parentId;
  final bool bookmarked;
  final double readingProgress;
  final int audioPositionMs;
  final String? remoteUid;
  final int contentVersion;
  bool get isRemote => remoteUid != null;

  Chronicle copyWith({
    bool? bookmarked,
    double? readingProgress,
    int? audioPositionMs,
  }) => Chronicle(
    id: id,
    templateId: templateId,
    siteId: siteId,
    title: title,
    voiceId: voiceId,
    genre: genre,
    style: style,
    mood: mood,
    seed: seed,
    image: image,
    createdAt: createdAt,
    parentId: parentId,
    remoteUid: remoteUid,
    contentVersion: contentVersion,
    bookmarked: bookmarked ?? this.bookmarked,
    readingProgress: readingProgress ?? this.readingProgress,
    audioPositionMs: audioPositionMs ?? this.audioPositionMs,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'templateId': templateId,
    'siteId': siteId,
    'title': title,
    'voiceId': voiceId,
    'genre': genre,
    'style': style,
    'mood': mood,
    'seed': seed,
    'image': image,
    'createdAt': createdAt.toIso8601String(),
    'parentId': parentId,
    'bookmarked': bookmarked,
    'readingProgress': readingProgress,
    'audioPositionMs': audioPositionMs,
    if (remoteUid != null) 'remoteUid': remoteUid,
    'contentVersion': contentVersion,
  };

  factory Chronicle.fromJson(Map<String, dynamic> json) => Chronicle(
    id: json['id'] as String,
    templateId: json['templateId'] as String,
    siteId: json['siteId'] as String,
    title: json['title'] as String,
    voiceId: json['voiceId'] as String,
    genre: json['genre'] as String,
    style: json['style'] as String,
    mood: json['mood'] as String,
    seed: json['seed'] as String,
    image: json['image'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    parentId: json['parentId'] as String?,
    bookmarked: json['bookmarked'] as bool? ?? false,
    readingProgress: (json['readingProgress'] as num? ?? 0).toDouble(),
    audioPositionMs: (json['audioPositionMs'] as num? ?? 0).toInt(),
    remoteUid: json['remoteUid'] as String?,
    contentVersion: json['contentVersion'] as int? ?? 1,
  );
}
