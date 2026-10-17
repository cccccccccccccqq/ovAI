/// Validated inputs and outputs for the authenticated callable API.
///
/// Constructors validate locally for immediate feedback. The backend repeats
/// every validation; these checks do not replace authorization or rules.
library;

String validateBackendId(String value, String field, {int maxLength = 96}) {
  if (value.isEmpty ||
      value.length > maxLength ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      field,
      'Use 1–$maxLength letters, numbers, _ or -, starting with a letter or number.',
    );
  }
  return value;
}

class EnsureProfileRequest {
  EnsureProfileRequest({required String displayName})
    : displayName = displayName.trim() {
    if (this.displayName.isEmpty ||
        this.displayName.length > 60 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(this.displayName)) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Use 1–60 characters on one line, without control characters.',
      );
    }
  }

  final String displayName;

  Map<String, Object> toJson() => {'displayName': displayName};
}

class CreatePreparedChronicleRequest {
  CreatePreparedChronicleRequest({
    required String requestId,
    required String templateId,
    required String voiceId,
  }) : requestId = validateBackendId(requestId, 'requestId', maxLength: 128),
       templateId = validateBackendId(templateId, 'templateId'),
       voiceId = validateBackendId(voiceId, 'voiceId');

  /// Keep this ID when retrying the same operation. Use a new ID for a new story.
  final String requestId;
  final String templateId;
  final String voiceId;

  Map<String, Object> toJson() => {
    'requestId': requestId,
    'templateId': templateId,
    'voiceId': voiceId,
  };
}

class PatchLibraryItemRequest {
  PatchLibraryItemRequest({
    required String chronicleId,
    this.bookmarked,
    this.readingProgress,
    this.audioPositionMs,
  }) : chronicleId = validateBackendId(chronicleId, 'chronicleId') {
    if (bookmarked == null &&
        readingProgress == null &&
        audioPositionMs == null) {
      throw ArgumentError('Include at least one library field to update.');
    }
    if (readingProgress != null &&
        (!readingProgress!.isFinite ||
            readingProgress! < 0 ||
            readingProgress! > 1)) {
      throw ArgumentError.value(readingProgress, 'readingProgress', 'Use 0–1.');
    }
    if (audioPositionMs != null &&
        (audioPositionMs! < 0 || audioPositionMs! > 86400000)) {
      throw ArgumentError.value(
        audioPositionMs,
        'audioPositionMs',
        'Use 0–86400000.',
      );
    }
  }

  final String chronicleId;
  final bool? bookmarked;
  final double? readingProgress;
  final int? audioPositionMs;

  Map<String, Object> toJson() => {
    'chronicleId': chronicleId,
    'bookmarked': ?bookmarked,
    'readingProgress': ?readingProgress,
    'audioPositionMs': ?audioPositionMs,
  };
}

enum BackendChronicleStatus { ready, deleted }

BackendChronicleStatus parseChronicleStatus(Object? value) => switch (value) {
  'ready' => BackendChronicleStatus.ready,
  'deleted' => BackendChronicleStatus.deleted,
  _ => throw FormatException('Unknown chronicle status: $value'),
};

class EnsureProfileResult {
  const EnsureProfileResult({required this.uid, required this.displayName});

  factory EnsureProfileResult.fromJson(Map<String, dynamic> json) =>
      EnsureProfileResult(
        uid: requireString(json, 'uid'),
        displayName: requireString(json, 'displayName'),
      );

  final String uid;
  final String displayName;
}

class CreatePreparedChronicleResult {
  const CreatePreparedChronicleResult({
    required this.chronicleId,
    required this.status,
    required this.replayed,
  });

  factory CreatePreparedChronicleResult.fromJson(Map<String, dynamic> json) =>
      CreatePreparedChronicleResult(
        chronicleId: requireString(json, 'chronicleId'),
        status: parseChronicleStatus(json['status']),
        replayed: requireBool(json, 'replayed'),
      );

  final String chronicleId;
  final BackendChronicleStatus status;
  final bool replayed;
}

class ChronicleMutationResult {
  const ChronicleMutationResult({
    required this.chronicleId,
    required this.status,
  });

  factory ChronicleMutationResult.fromJson(Map<String, dynamic> json) =>
      ChronicleMutationResult(
        chronicleId: requireString(json, 'chronicleId'),
        status: parseChronicleStatus(json['status']),
      );

  final String chronicleId;
  final BackendChronicleStatus status;
}

String requireString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) throw FormatException('$field must be a string.');
  return value;
}

String? optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  return requireString(json, field);
}

bool requireBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! bool) throw FormatException('$field must be a boolean.');
  return value;
}

double requireNumber(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! num || !value.isFinite) {
    throw FormatException('$field must be a finite number.');
  }
  return value.toDouble();
}

int requireInteger(Map<String, dynamic> json, String field) {
  final value = requireNumber(json, field);
  if (value != value.truncateToDouble()) {
    throw FormatException('$field must be an integer.');
  }
  return value.toInt();
}

Map<String, dynamic> requireObject(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be an object.');
  }
  return Map<String, dynamic>.from(value);
}
