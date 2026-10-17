import 'package:cloud_firestore/cloud_firestore.dart';

import 'backend_contracts.dart';

DateTime requireTimestamp(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! Timestamp) {
    throw FormatException('$field must be a Firestore Timestamp.');
  }
  return value.toDate().toUtc();
}

List<T> _objects<T>(
  Map<String, dynamic> json,
  String field,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[field];
  if (value is! List) throw FormatException('$field must be a list.');
  return List<T>.unmodifiable(
    value.map((item) => parse(requireObject(item, field))),
  );
}

List<String> _strings(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field must be a list of strings.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

class BackendProfile {
  const BackendProfile({
    required this.uid,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackendProfile.fromDocument(String uid, Map<String, dynamic> json) =>
      BackendProfile(
        uid: uid,
        displayName: requireString(json, 'displayName'),
        createdAt: requireTimestamp(json, 'createdAt'),
        updatedAt: requireTimestamp(json, 'updatedAt'),
      );

  final String uid;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BackendSite {
  const BackendSite({
    required this.id,
    required this.name,
    required this.nameMn,
    required this.summary,
    required this.lat,
    required this.lng,
    required this.era,
    this.imagePath,
  });

  factory BackendSite.fromDocument(String id, Map<String, dynamic> json) =>
      BackendSite(
        id: id,
        name: requireString(json, 'name'),
        nameMn: requireString(json, 'nameMn'),
        summary: requireString(json, 'summary'),
        lat: requireNumber(json, 'lat'),
        lng: requireNumber(json, 'lng'),
        era: requireString(json, 'era'),
        imagePath: optionalString(json, 'imagePath'),
      );

  final String id;
  final String name;
  final String nameMn;
  final String summary;
  final double lat;
  final double lng;
  final String era;
  final String? imagePath;
}

class BackendStorySegment {
  const BackendStorySegment({
    required this.text,
    required this.kind,
    this.citationId,
  });

  factory BackendStorySegment.fromJson(Map<String, dynamic> json) =>
      BackendStorySegment(
        text: requireString(json, 'text'),
        kind: requireString(json, 'kind'),
        citationId: optionalString(json, 'citationId'),
      );

  final String text;
  final String kind;
  final String? citationId;
}

class BackendCitation {
  const BackendCitation({
    required this.id,
    required this.title,
    required this.author,
    required this.page,
    required this.note,
    this.url,
  });

  factory BackendCitation.fromJson(Map<String, dynamic> json) =>
      BackendCitation(
        id: requireString(json, 'id'),
        title: requireString(json, 'title'),
        author: requireString(json, 'author'),
        page: requireString(json, 'page'),
        note: requireString(json, 'note'),
        url: optionalString(json, 'url'),
      );

  final String id;
  final String title;
  final String author;
  final String page;
  final String note;
  final String? url;
}

/// The actual text and citations, copied into each private chronicle by server.
/// A saved chronicle remains readable when its source template changes.
class BackendStoryContent {
  const BackendStoryContent({
    required this.siteId,
    required this.title,
    required this.subtitle,
    required this.genre,
    required this.style,
    required this.mood,
    required this.seed,
    required this.chapter,
    required this.segments,
    required this.citations,
    required this.nextIds,
    this.imagePath,
  });

  factory BackendStoryContent.fromJson(Map<String, dynamic> json) =>
      BackendStoryContent(
        siteId: requireString(json, 'siteId'),
        title: requireString(json, 'title'),
        subtitle: requireString(json, 'subtitle'),
        genre: requireString(json, 'genre'),
        style: requireString(json, 'style'),
        mood: requireString(json, 'mood'),
        seed: requireString(json, 'seed'),
        chapter: requireInteger(json, 'chapter'),
        segments: _objects(json, 'segments', BackendStorySegment.fromJson),
        citations: _objects(json, 'citations', BackendCitation.fromJson),
        nextIds: _strings(json, 'nextIds'),
        imagePath: optionalString(json, 'imagePath'),
      );

  final String siteId;
  final String title;
  final String subtitle;
  final String genre;
  final String style;
  final String mood;
  final String seed;
  final int chapter;
  final List<BackendStorySegment> segments;
  final List<BackendCitation> citations;
  final List<String> nextIds;
  final String? imagePath;

  String get plainText => segments.map((segment) => segment.text).join('\n\n');
}

class BackendTemplateAudio {
  const BackendTemplateAudio({required this.storagePath, required this.status});

  factory BackendTemplateAudio.fromJson(Map<String, dynamic> json) =>
      BackendTemplateAudio(
        storagePath: requireString(json, 'storagePath'),
        status: requireString(json, 'status'),
      );

  final String storagePath;
  final String status;
}

class BackendStoryTemplate {
  const BackendStoryTemplate({
    required this.id,
    required this.status,
    required this.contentVersion,
    required this.language,
    required this.contentKind,
    required this.content,
    required this.voiceIds,
    required this.audioByVoice,
  });

  factory BackendStoryTemplate.fromDocument(
    String id,
    Map<String, dynamic> json,
  ) {
    final audio = requireObject(json['audioByVoice'], 'audioByVoice');
    return BackendStoryTemplate(
      id: id,
      status: requireString(json, 'status'),
      contentVersion: requireInteger(json, 'contentVersion'),
      language: requireString(json, 'language'),
      contentKind: requireString(json, 'contentKind'),
      content: BackendStoryContent.fromJson(json),
      voiceIds: _strings(json, 'voiceIds'),
      audioByVoice: Map<String, BackendTemplateAudio>.unmodifiable(
        audio.map(
          (voiceId, value) => MapEntry(
            voiceId,
            BackendTemplateAudio.fromJson(
              requireObject(value, 'audioByVoice.$voiceId'),
            ),
          ),
        ),
      ),
    );
  }

  final String id;
  final String status;
  final int contentVersion;
  final String language;
  final String contentKind;
  final BackendStoryContent content;
  final List<String> voiceIds;
  final Map<String, BackendTemplateAudio> audioByVoice;
}

enum BackendAudioStatus { ready, unavailable }

class BackendChronicle {
  const BackendChronicle({
    required this.id,
    required this.uid,
    required this.templateId,
    required this.voiceId,
    required this.language,
    required this.contentVersion,
    required this.contentKind,
    required this.content,
    required this.status,
    required this.audioStatus,
    required this.createdAt,
    required this.updatedAt,
    this.audioPath,
  });

  factory BackendChronicle.fromDocument(String id, Map<String, dynamic> json) =>
      BackendChronicle(
        id: id,
        uid: requireString(json, 'uid'),
        templateId: requireString(json, 'templateId'),
        voiceId: requireString(json, 'voiceId'),
        language: requireString(json, 'language'),
        contentVersion: requireInteger(json, 'contentVersion'),
        contentKind: requireString(json, 'contentKind'),
        content: BackendStoryContent.fromJson(json),
        status: parseChronicleStatus(json['status']),
        audioStatus: switch (json['audioStatus']) {
          'ready' => BackendAudioStatus.ready,
          'unavailable' => BackendAudioStatus.unavailable,
          _ => throw FormatException(
            'Unknown audio status: ${json['audioStatus']}',
          ),
        },
        audioPath: optionalString(json, 'audioPath'),
        createdAt: requireTimestamp(json, 'createdAt'),
        updatedAt: requireTimestamp(json, 'updatedAt'),
      );

  final String id;
  final String uid;
  final String templateId;
  final String voiceId;
  final String language;
  final int contentVersion;
  final String contentKind;
  final BackendStoryContent content;
  final BackendChronicleStatus status;
  final BackendAudioStatus audioStatus;
  final String? audioPath;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BackendLibraryItem {
  const BackendLibraryItem({
    required this.id,
    required this.uid,
    required this.chronicleId,
    required this.title,
    required this.siteId,
    required this.voiceId,
    required this.contentKind,
    required this.bookmarked,
    required this.readingProgress,
    required this.audioPositionMs,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
  });

  factory BackendLibraryItem.fromDocument(
    String id,
    Map<String, dynamic> json,
  ) => BackendLibraryItem(
    id: id,
    uid: requireString(json, 'uid'),
    chronicleId: requireString(json, 'chronicleId'),
    title: requireString(json, 'title'),
    siteId: requireString(json, 'siteId'),
    voiceId: requireString(json, 'voiceId'),
    contentKind: requireString(json, 'contentKind'),
    bookmarked: requireBool(json, 'bookmarked'),
    readingProgress: requireNumber(json, 'readingProgress'),
    audioPositionMs: requireInteger(json, 'audioPositionMs'),
    imagePath: optionalString(json, 'imagePath'),
    createdAt: requireTimestamp(json, 'createdAt'),
    updatedAt: requireTimestamp(json, 'updatedAt'),
  );

  final String id;
  final String uid;
  final String chronicleId;
  final String title;
  final String siteId;
  final String voiceId;
  final String contentKind;
  final bool bookmarked;
  final double readingProgress;
  final int audioPositionMs;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
}
