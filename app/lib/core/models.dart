/// Curated content and local records for the ÖV interactive prototype.
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
  });

  final String id;
  final String name;
  final String nameMn;
  final String summary;
  final double lat;
  final double lng;
  final String image;
  final String era;
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

  String get plainText => segments.map((segment) => segment.text).join('\n\n');
  int get readingMinutes => (plainText.split(RegExp(r'\s+')).length / 180)
      .ceil()
      .clamp(1, 60)
      .toInt();
  bool get isDemo => true;
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
  );
}
