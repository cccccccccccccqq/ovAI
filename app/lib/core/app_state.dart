import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';
import 'models.dart';

/// Device-local prepared content and preferences, isolated by account when used
/// with authenticated sessions. This class does not perform cloud persistence.
class AppState extends ChangeNotifier {
  AppState._(
    this._preferences, {
    required String preferenceKey,
    String? accountDisplayName,
  }) : _preferenceKey = preferenceKey,
       _accountDisplayName = accountDisplayName;

  static const storageKey = 'ov.prototype.state.v1';
  final SharedPreferences _preferences;
  // Each instance keeps its own storage destination, including writes that
  // finish after the app has switched to another signed-in account.
  final String _preferenceKey;
  final String? _accountDisplayName;
  Future<void> _pendingWrite = Future<void>.value();
  int _sequence = 0;
  bool _isGuest = false;
  String? _profileName;
  bool _offline = false;
  bool _darkMode = false;
  double _textScale = 1;
  double _playbackSpeed = 1;
  ChronicleDraft _draft = _initialDraft();
  final List<Chronicle> _library = [];
  final Set<String> _bookmarkedSiteIds = {};
  final List<ChronicleDraft> _queuedDrafts = [];
  final Set<String> _installedPacks = {};

  static ChronicleDraft _initialDraft() {
    final template = demoTemplates.first;
    return ChronicleDraft(
      id: 'current-draft',
      siteId: template.siteId,
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
      voiceId: demoVoices.first.id,
    );
  }

  /// Restore the original demo/guest session without importing account data.
  static Future<AppState> load() => _load(preferenceKey: storageKey);

  /// Restore only this Firebase account's local preferences and prepared stories.
  ///
  /// The environment is part of the key because live and emulator UIDs can be
  /// identical. The authenticated name overrides any previously saved profile.
  static Future<AppState> loadForAccount({
    required String uid,
    required String displayName,
    required String environment,
  }) async {
    if (uid.trim().isEmpty || uid.length > 128) {
      throw ArgumentError.value(uid, 'uid', 'Use a UID of 1–128 characters.');
    }
    if (environment != 'live' && environment != 'emulator') {
      throw ArgumentError.value(
        environment,
        'environment',
        'Use live or emulator.',
      );
    }
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'Enter a name.');
    }
    final encodedUid = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return _load(
      preferenceKey: 'ov.account.state.v1.$environment.$encodedUid',
      accountDisplayName: name,
    );
  }

  static Future<AppState> _load({
    required String preferenceKey,
    String? accountDisplayName,
  }) async {
    final state = AppState._(
      await SharedPreferences.getInstance(),
      preferenceKey: preferenceKey,
      accountDisplayName: accountDisplayName,
    );
    final saved = state._preferences.getString(preferenceKey);
    if (saved == null) return state;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      if (json['version'] != 1) return state;
      state._profileName = json['profileName'] as String?;
      state._isGuest = json['isGuest'] as bool? ?? false;
      state._offline = json['offline'] as bool? ?? false;
      state._darkMode = json['darkMode'] as bool? ?? false;
      state._textScale = _bounded(json['textScale'], 1, 0.85, 1.5);
      state._playbackSpeed = _bounded(json['playbackSpeed'], 1, 0.5, 2);
      if (json['draft'] is Map<String, dynamic>) {
        state._draft = state._normalizeDraft(
          ChronicleDraft.fromJson(json['draft'] as Map<String, dynamic>),
        );
      }
      for (final value in json['library'] as List<dynamic>? ?? []) {
        try {
          final story = Chronicle.fromJson(value as Map<String, dynamic>);
          if (demoTemplates.any((item) => item.id == story.templateId) &&
              demoSites.any((item) => item.id == story.siteId) &&
              demoVoices.any((item) => item.id == story.voiceId)) {
            state._library.add(
              story.copyWith(
                readingProgress: _bounded(story.readingProgress, 0, 0, 1),
                audioPositionMs: story.audioPositionMs
                    .clamp(0, 86400000)
                    .toInt(),
              ),
            );
          }
        } on Object {
          // A single invalid local record must not hide the rest of the library.
        }
      }
      state._bookmarkedSiteIds.addAll(
        (json['bookmarkedSiteIds'] as List<dynamic>? ?? [])
            .whereType<String>()
            .where((id) => demoSites.any((site) => site.id == id)),
      );
      for (final value in json['queuedDrafts'] as List<dynamic>? ?? []) {
        try {
          state._queuedDrafts.add(
            state._normalizeDraft(
              ChronicleDraft.fromJson(value as Map<String, dynamic>),
            ),
          );
        } on Object {
          // Invalid queue records are skipped independently.
        }
      }
      state._installedPacks.addAll(
        (json['installedPacks'] as List<dynamic>? ?? [])
            .whereType<String>()
            .where((id) => demoSites.any((site) => site.id == id)),
      );
    } on Object {
      // Invalid preferences are recoverable; next mutation writes clean state.
      return AppState._(
        state._preferences,
        preferenceKey: preferenceKey,
        accountDisplayName: accountDisplayName,
      );
    }
    return state;
  }

  static double _bounded(
    Object? value,
    double fallback,
    double min,
    double max,
  ) {
    if (value is! num || !value.isFinite) return fallback;
    return value.toDouble().clamp(min, max).toDouble();
  }

  List<Site> get sites => demoSites;
  List<StoryTemplate> get templates => demoTemplates;
  List<DemoVoice> get voices => demoVoices;
  List<Chronicle> get library => List.unmodifiable(_library);
  Site get selectedSite => siteById(_draft.siteId);
  ChronicleDraft get draft => _draft;
  String? get profileName => _accountDisplayName ?? _profileName;
  bool get isGuest => _accountDisplayName == null && _isGuest;
  bool get offline => _offline;
  bool get darkMode => _darkMode;
  double get textScale => _textScale;
  double get playbackSpeed => _playbackSpeed;
  Set<String> get bookmarkedSiteIds => Set.unmodifiable(_bookmarkedSiteIds);
  List<ChronicleDraft> get queuedDrafts => List.unmodifiable(_queuedDrafts);
  Set<String> get installedPacks => Set.unmodifiable(_installedPacks);
  StoryTemplate get draftTemplate => _templateForDraft(_draft);

  Site siteById(String id) => demoSites.firstWhere(
    (site) => site.id == id,
    orElse: () => demoSites.first,
  );

  DemoVoice voiceById(String id) => demoVoices.firstWhere(
    (voice) => voice.id == id,
    orElse: () => demoVoices.first,
  );

  StoryTemplate templateById(String id) => demoTemplates.firstWhere(
    (template) => template.id == id,
    orElse: () => demoTemplates.first,
  );

  StoryTemplate templateFor(Chronicle story) => templateById(story.templateId);

  Chronicle? storyById(String id) {
    for (final story in _library) {
      if (story.id == id) return story;
    }
    return null;
  }

  List<StoryTemplate> templatesForSite(String siteId) => demoTemplates
      .where((template) => template.siteId == siteId)
      .toList(growable: false);

  StoryTemplate defaultTemplateForSite(String siteId) =>
      demoTemplates.firstWhere(
        (template) => template.siteId == siteId && template.chapter == 1,
        orElse: () => demoTemplates.first,
      );

  List<Citation> citationsFor(StoryTemplate template) {
    final ids = template.segments
        .map((segment) => segment.citationId)
        .whereType<String>()
        .toSet();
    return demoCitations
        .where((citation) => ids.contains(citation.id))
        .toList();
  }

  String audioAssetFor(Chronicle story) =>
      'assets/audio/${story.voiceId}/${story.templateId}.m4a';

  StoryTemplate _templateForDraft(ChronicleDraft value) {
    final options = templatesForSite(
      value.siteId,
    ).where((template) => template.chapter == 1).toList();
    for (final template in options) {
      if (template.genre == value.genre && template.seed == value.seed) {
        return template;
      }
    }
    return options.firstWhere(
      (template) => template.genre == value.genre,
      orElse: () => options.first,
    );
  }

  ChronicleDraft _normalizeDraft(ChronicleDraft value) {
    final site = siteById(value.siteId);
    final template = _templateForDraft(value.copyWith(siteId: site.id));
    return value.copyWith(
      siteId: site.id,
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
      voiceId: voiceById(value.voiceId).id,
    );
  }

  Future<void> selectSite(String id) async {
    final site = siteById(id);
    if (_draft.siteId == site.id) return;
    final template = defaultTemplateForSite(site.id);
    _draft = ChronicleDraft(
      id: 'current-draft',
      siteId: site.id,
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
      voiceId: _draft.voiceId,
    );
    await _changed();
  }

  /// Prepared presets keep story text, selected metadata and audio consistent.
  /// Choosing a seed, genre, style or mood selects an available matching preset.
  Future<void> updateDraft({
    String? siteId,
    String? genre,
    String? style,
    String? mood,
    String? seed,
    String? voiceId,
    String? coverPath,
    bool clearCover = false,
  }) async {
    if (siteId != null && siteId != _draft.siteId) await selectSite(siteId);
    final options = templatesForSite(
      _draft.siteId,
    ).where((template) => template.chapter == 1).toList();
    var template = draftTemplate;
    final matches = options.where(
      (item) =>
          (genre == null || item.genre == genre) &&
          (style == null || item.style == style) &&
          (mood == null || item.mood == mood) &&
          (seed == null || item.seed == seed),
    );
    final changesPreset =
        genre != null || style != null || mood != null || seed != null;
    if (changesPreset) {
      if (matches.isEmpty) {
        throw ArgumentError('Choose an available prepared story preset.');
      }
      template = matches.first;
    }
    _draft = _draft.copyWith(
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
      voiceId: voiceId == null ? null : voiceById(voiceId).id,
      coverPath: coverPath,
      clearCover: clearCover,
    );
    await _changed();
  }

  Future<void> clearDraftCover() => updateDraft(clearCover: true);

  Future<void> setProfile(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 40) {
      throw ArgumentError('Enter a name between 1 and 40 characters.');
    }
    _profileName = cleanName;
    _isGuest = false;
    await _changed();
  }

  Future<void> enterGuest() async {
    _profileName = null;
    _isGuest = true;
    await _changed();
  }

  Future<void> signOut() async {
    _profileName = null;
    _isGuest = false;
    await _changed();
  }

  Future<void> setOffline(bool value) async {
    _offline = value;
    await _changed();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _changed();
  }

  Future<void> setTextScale(double value) async {
    _textScale = _bounded(value, 1, 0.85, 1.5);
    await _changed();
  }

  Future<void> setPlaybackSpeed(double value) async {
    _playbackSpeed = _bounded(value, 1, 0.5, 2);
    await _changed();
  }

  Future<void> toggleSiteBookmark(String id) async {
    if (!demoSites.any((site) => site.id == id)) return;
    if (!_bookmarkedSiteIds.remove(id)) _bookmarkedSiteIds.add(id);
    await _changed();
  }

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Future<Chronicle> createChronicle({
    String? templateId,
    String? parentId,
  }) async {
    final template = templateId == null
        ? draftTemplate
        : demoTemplates.firstWhere(
            (item) => item.id == templateId,
            orElse: () => throw ArgumentError('Unknown prepared story.'),
          );
    final parent = parentId == null ? null : storyById(parentId);
    if (parentId != null && parent == null) {
      throw ArgumentError('The previous chapter is no longer in your library.');
    }
    if (parent != null && !templateFor(parent).nextIds.contains(template.id)) {
      throw ArgumentError(
        'Choose one of this chapter’s prepared continuations.',
      );
    }
    final story = Chronicle(
      id: _nextId('chronicle'),
      templateId: template.id,
      siteId: template.siteId,
      title: template.title,
      voiceId: parent?.voiceId ?? _draft.voiceId,
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
      image:
          parent?.image ??
          (template.siteId == _draft.siteId ? _draft.coverPath : null) ??
          template.image,
      createdAt: DateTime.now(),
      parentId: parentId,
    );
    _library.insert(0, story);
    await _changed();
    return story;
  }

  Future<void> toggleStoryBookmark(String id) async {
    final index = _library.indexWhere((story) => story.id == id);
    if (index < 0) return;
    final story = _library[index];
    _library[index] = story.copyWith(bookmarked: !story.bookmarked);
    await _changed();
  }

  Future<void> deleteChronicle(String id) async {
    _library.removeWhere((story) => story.id == id);
    await _changed();
  }

  Future<void> saveProgress(String id, double progress, int positionMs) async {
    final index = _library.indexWhere((story) => story.id == id);
    if (index < 0) return;
    _library[index] = _library[index].copyWith(
      readingProgress: _bounded(progress, 0, 0, 1),
      audioPositionMs: positionMs.clamp(0, 86400000).toInt(),
    );
    await _changed();
  }

  Future<void> queueDraft() async {
    _queuedDrafts.add(_draft.copyWith(id: _nextId('queued')));
    await _changed();
  }

  Future<void> removeQueuedDraft(String id) async {
    _queuedDrafts.removeWhere((draft) => draft.id == id);
    await _changed();
  }

  /// Restore a queued selection for editing or to resume its local demo job.
  Future<void> restoreQueuedDraft(String id) async {
    final value = _queuedDrafts.firstWhere(
      (draft) => draft.id == id,
      orElse: () => throw ArgumentError('This queued draft no longer exists.'),
    );
    _draft = _normalizeDraft(value.copyWith(id: 'current-draft'));
    await _changed();
  }

  /// Pack file copying is performed by the device adapter before this is called.
  Future<void> setPackInstalled(String id, bool installed) async {
    if (!demoSites.any((site) => site.id == id)) return;
    if (installed) {
      _installedPacks.add(id);
    } else {
      _installedPacks.remove(id);
    }
    await _changed();
  }

  Future<void> resetDemo() async {
    _profileName = null;
    _isGuest = false;
    _offline = false;
    _darkMode = false;
    _textScale = 1;
    _playbackSpeed = 1;
    _draft = _initialDraft();
    _library.clear();
    _bookmarkedSiteIds.clear();
    _queuedDrafts.clear();
    _installedPacks.clear();
    await _changed();
  }

  Future<void> _changed() {
    final encoded = jsonEncode({
      'version': 1,
      'profileName': profileName,
      'isGuest': isGuest,
      'offline': _offline,
      'darkMode': _darkMode,
      'textScale': _textScale,
      'playbackSpeed': _playbackSpeed,
      'draft': _draft.toJson(),
      'library': _library.map((story) => story.toJson()).toList(),
      'bookmarkedSiteIds': _bookmarkedSiteIds.toList(),
      'queuedDrafts': _queuedDrafts.map((draft) => draft.toJson()).toList(),
      'installedPacks': _installedPacks.toList(),
    });
    // Capture this revision now and write serially so a slower old save cannot
    // overwrite a more recent selection or playback position.
    final save = _pendingWrite.catchError((Object _) {}).then((_) async {
      final written = await _preferences.setString(_preferenceKey, encoded);
      if (!written) throw StateError('Unable to save the local state.');
    });
    _pendingWrite = save;
    notifyListeners();
    return save;
  }
}
