import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';
import 'models.dart';
import '../history/history_store.dart';
import '../history/chapter_models.dart';

/// Device-local prepared content and preferences, isolated by account when used
/// with authenticated sessions. Cloud sessions keep prepared story records in the selected Firebase backend.
class AppState extends ChangeNotifier {
  AppState._(
    this._preferences, {
    required String preferenceKey,
    String? accountDisplayName,
    String? cloudProjectId,
  }) : _cloudProjectId = cloudProjectId,
       _preferenceKey = preferenceKey,
       _accountDisplayName = accountDisplayName;

  static const storageKey = 'ov.prototype.state.v1';
  final SharedPreferences _preferences;
  final String? _cloudProjectId;
  bool get usesCloudBackend => _cloudProjectId != null;
  // Each instance keeps its own storage destination, including writes that
  // finish after the app has switched to another signed-in account.
  final String _preferenceKey;
  final String? _accountDisplayName;
  Future<void> _pendingWrite = Future<void>.value();
  int _sequence = 0;
  List<Site> _sites = List.of(demoSites);
  List<StoryTemplate> _templates = List.of(demoTemplates);
  Map<String, dynamic>? _historyCatalogCache;
  final Map<String, StoryTemplate> _savedTemplates = {};
  final Map<String, HistoricalPlace> _historicalPlaces = {};
  HistoryStore? _historyStore;
  String? _historyCatalogError;
  String? _historySyncError;
  final Map<String, Map<String, Object>> _pendingHistoryPatches = {};
  final Map<String, Future<void>> _historyWrites = {};

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
  static Future<AppState> load({String? projectId}) => _load(
    preferenceKey: projectId == null
        ? storageKey
        : 'ov.cloud.guest.state.v1.${_projectNamespace(projectId)}',
    cloudProjectId: projectId,
  );

  static String _projectNamespace(String projectId) {
    if (!RegExp(r'^[a-z][a-z0-9-]{4,61}[a-z0-9]$').hasMatch(projectId)) {
      throw ArgumentError.value(
        projectId,
        'projectId',
        'Use a Firebase project ID.',
      );
    }
    return projectId;
  }

  /// Restore only this Firebase account's local preferences and prepared stories.
  ///
  /// The environment is part of the key because live and emulator UIDs can be
  /// identical. The authenticated name overrides any previously saved profile.
  static Future<AppState> loadForAccount({
    required String uid,
    required String displayName,
    required String environment,
    String? projectId,
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
    if (environment == 'emulator' && projectId != null) {
      throw ArgumentError(
        'Cloud project IDs cannot be used in emulator account caches.',
      );
    }
    final namespace = projectId == null
        ? environment
        : '$environment.${_projectNamespace(projectId)}';
    return _load(
      preferenceKey: 'ov.account.state.v1.$namespace.$encodedUid',
      accountDisplayName: name,
      cloudProjectId: projectId,
    );
  }

  static Future<AppState> _load({
    required String preferenceKey,
    String? accountDisplayName,
    String? cloudProjectId,
  }) async {
    final state = AppState._(
      await SharedPreferences.getInstance(),
      preferenceKey: preferenceKey,
      accountDisplayName: accountDisplayName,
      cloudProjectId: cloudProjectId,
    );
    final saved = state._preferences.getString(preferenceKey);
    if (saved == null) return state;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      if (json['version'] != 1) return state;
      if (json['historyCatalog'] is Map) {
        state._applyHistoryCatalog(
          Map<String, dynamic>.from(json['historyCatalog'] as Map),
        );
      }
      for (final entry
          in (json['savedTemplates'] as Map<String, dynamic>? ?? {}).entries) {
        state._savedTemplates[entry.key] = StoryTemplate.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
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
          if (state._templates.any((item) => item.id == story.templateId) &&
              state._sites.any((item) => item.id == story.siteId) &&
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
            .where((id) => state._sites.any((site) => site.id == id)),
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
            .where((id) => state._sites.any((site) => site.id == id)),
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

  List<Site> get sites => List.unmodifiable(_sites);
  List<StoryTemplate> get templates => List.unmodifiable(_templates);
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

  Site siteById(String id) =>
      _sites.firstWhere((site) => site.id == id, orElse: () => _sites.first);

  DemoVoice voiceById(String id) => demoVoices.firstWhere(
    (voice) => voice.id == id,
    orElse: () => demoVoices.first,
  );

  StoryTemplate templateById(String id) => _templates.firstWhere(
    (template) => template.id == id,
    orElse: () => _templates.first,
  );

  StoryTemplate templateFor(Chronicle story) =>
      _savedTemplates[story.id] ?? templateById(story.templateId);

  Chronicle? storyById(String id) {
    for (final story in _library) {
      if (story.id == id) return story;
    }
    return null;
  }

  List<StoryTemplate> templatesForSite(String siteId) => _templates
      .where((template) => template.siteId == siteId)
      .toList(growable: false);

  StoryTemplate defaultTemplateForSite(String siteId) => _templates.firstWhere(
    (template) => template.siteId == siteId && template.chapter == 1,
    orElse: () => _templates.first,
  );

  List<Citation> citationsFor(StoryTemplate template) {
    if (template.citations.isNotEmpty) return template.citations;
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
    if (!_sites.any((site) => site.id == id)) return;
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
        : _templates.firstWhere(
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
    final selectedVoice = parent?.voiceId ?? _draft.voiceId;
    // Bundled Orkhon stories open locally for anyone without a cloud account,
    // so guests can read them; signed-in readers still save to the cloud.
    final cloudAccount = _historyStore?.uid.isNotEmpty == true && !_offline;
    if (template.isHistorical || (usesCloudBackend && cloudAccount)) {
      final store = _historyStore;
      if (store == null || _offline) {
        throw StateError(
          'Connect to the backend before preparing this chapter.',
        );
      }
      if (store.uid.isEmpty) {
        throw StateError('Sign in with Google or Apple to save this story.');
      }
      final snapshot = await store.create(
        requestId: _nextId('prepared'),
        templateId: template.id,
        voiceId: selectedVoice,
        parentId: parent?.id,
      );
      final story = _storyFromSnapshot(
        snapshot,
        const {},
        parentId: parent?.id,
        customImage:
            parent?.image ??
            (template.siteId == _draft.siteId ? _draft.coverPath : null),
      );
      _library.insert(0, story);
      await _changed();
      return story;
    }
    final story = Chronicle(
      id: _nextId('chronicle'),
      templateId: template.id,
      siteId: template.siteId,
      title: template.title,
      voiceId: selectedVoice,
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
    if (story.isRemote) {
      await _queueHistoryPatch(story, {'bookmarked': !story.bookmarked});
    }
  }

  Future<void> deleteChronicle(String id) async {
    final story = storyById(id);
    if (story?.isRemote == true) {
      await flushHistoryWrites();
      final store = _historyStore;
      if (store == null || story!.remoteUid != store.uid) {
        throw StateError('Sign in again before deleting this story.');
      }
      await store.delete(id);
    }
    _savedTemplates.remove(id);
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
    final story = _library[index];
    await _changed();
    if (story.isRemote) {
      await _queueHistoryPatch(story, {
        'readingProgress': story.readingProgress,
        'audioPositionMs': story.audioPositionMs,
      });
    }
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
    if (!_sites.any((site) => site.id == id)) return;
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

  Map<String, HistoricalPlace> get historicalPlaces =>
      Map.unmodifiable(_historicalPlaces);
  String? get historyCatalogError => _historyCatalogError;
  String? get historySyncError => _historySyncError;

  /// Optional test double keeps existing widget tests independent of Firebase.
  Future<void> loadHistoricalCatalog({HistoryStore? store}) async {
    try {
      _historyStore =
          store ?? await FirebaseHistoryStore.connect(_preferenceKey);
      final catalog = await _historyStore!.loadCatalog();
      _applyHistoryCatalog(catalog);
      final snapshots = await _historyStore!.loadLibrary();
      final old = {
        for (final story in _library.where((s) => s.isRemote)) story.id: story,
      };
      _library.removeWhere((story) => story.isRemote);
      _savedTemplates.removeWhere((id, _) => old.containsKey(id));
      for (final value in snapshots) {
        final snapshot = Map<String, dynamic>.from(value['chronicle'] as Map);
        final progress = Map<String, dynamic>.from(value['library'] as Map);
        final cached = old[snapshot['id']];
        try {
          _library.add(
            _storyFromSnapshot(
              snapshot,
              progress,
              parentId: snapshot['parentId'] as String? ?? cached?.parentId,
              customImage: cached?.image,
            ),
          );
        } on FormatException {
          // One invalid or foreign record cannot replace this owner's library.
        }
      }
      _library.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _historyCatalogError = null;
      _historySyncError = null;
      await _changed();
    } catch (_) {
      _historyCatalogError =
          'Stories are unavailable. Check your connection and retry.';
      notifyListeners();
    }
  }

  void _applyHistoryCatalog(Map<String, dynamic> data) {
    final incomingSites = (data['sites'] as List)
        .map((v) => Site.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    final incomingTemplates = (data['templates'] as List)
        .map((v) => StoryTemplate.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    if (incomingTemplates.any(
          (t) =>
              t.language != 'en' ||
              (usesCloudBackend
                  ? !const {
                      'prepared-demo',
                      'historical-synopsis',
                    }.contains(t.contentKind)
                  : !t.isHistorical),
        ) ||
        incomingSites.isEmpty) {
      throw const FormatException(
        'Expected a published English story catalog.',
      );
    }
    // Bundled records are available offline; cloud records override the same
    // IDs without duplicating places or changing the established UI order.
    _sites = {
      for (final s in [...demoSites, ...incomingSites]) s.id: s,
    }.values.toList();
    _templates = {
      for (final t in [...demoTemplates, ...incomingTemplates]) t.id: t,
    }.values.toList();
    _historicalPlaces.clear();
    final places = <Map<String, dynamic>>[];
    for (final value in data['historicalPlaces'] as List? ?? []) {
      final raw = Map<String, dynamic>.from(value as Map);
      final place = HistoricalPlace.fromDocument(raw['id'] as String, raw);
      _historicalPlaces[place.id] = place;
      places.add({
        'id': place.id,
        'historicalName': place.name,
        'modernName': place.modernName,
        'center': {'latitude': place.latitude, 'longitude': place.longitude},
        'radiusMeters': place.radiusMeters,
        'confidence': place.confidence,
        'description': place.description,
      });
    }
    _historyCatalogCache = {
      'sites': incomingSites.map((v) => v.toJson()).toList(),
      'templates': incomingTemplates.map((v) => v.toJson()).toList(),
      'historicalPlaces': places,
    };
  }

  Chronicle _storyFromSnapshot(
    Map<String, dynamic> snapshot,
    Map<String, dynamic> progress, {
    String? parentId,
    String? customImage,
  }) {
    final owner = _historyStore?.uid;
    if (owner == null ||
        owner.isEmpty ||
        snapshot['uid'] != owner ||
        snapshot['status'] != 'ready') {
      throw const FormatException(
        'A saved story must belong to the active account.',
      );
    }
    final id = snapshot['id'] as String;
    final templateId = snapshot['templateId'] as String;
    final audioPath = snapshot['audioPath'] as String;
    final template = StoryTemplate.fromJson({
      ...snapshot,
      'id': templateId,
      'audioByVoice': {snapshot['voiceId'] as String: audioPath},
    });
    final created = snapshot['createdAt'];
    final date = created is DateTime
        ? created
        : created is String
        ? DateTime.parse(created)
        : created != null
        ? (created as dynamic).toDate() as DateTime
        : DateTime.now();
    _savedTemplates[id] = template;
    return Chronicle(
      id: id,
      templateId: templateId,
      siteId: template.siteId,
      title: template.title,
      voiceId: snapshot['voiceId'] as String,
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
      image: customImage ?? template.image,
      createdAt: date,
      parentId: parentId ?? snapshot['parentId'] as String?,
      bookmarked: progress['bookmarked'] == true,
      readingProgress: _bounded(progress['readingProgress'], 0, 0, 1),
      audioPositionMs: ((progress['audioPositionMs'] as num?)?.toInt() ?? 0)
          .clamp(0, template.durationMs ?? 240000),
      remoteUid: snapshot['uid'] as String,
      contentVersion: template.contentVersion,
    );
  }

  Future<Uri?> remoteAudioUriFor(Chronicle story) async {
    if (!story.isRemote || _offline) return null;
    final store = _historyStore;
    if (store == null || store.uid != story.remoteUid) {
      throw StateError('Sign in again to reconnect your story library.');
    }
    final path = templateFor(story).audioByVoice[story.voiceId];
    if (path == null) throw StateError('This narrator is unavailable.');
    return Uri.parse(await store.audioUrl(path));
  }

  Future<void> _queueHistoryPatch(Chronicle story, Map<String, Object> values) {
    final store = _historyStore;
    if (store == null || store.uid != story.remoteUid) {
      _historySyncError =
          'Changes are saved on this device. Reconnect to sync this story.';
      return Future.value();
    }
    _pendingHistoryPatches[story.id] = {
      ...?_pendingHistoryPatches[story.id],
      ...values,
    };
    return _historyWrites.putIfAbsent(story.id, () async {
      try {
        while (_pendingHistoryPatches.containsKey(story.id)) {
          final patch = _pendingHistoryPatches.remove(story.id)!;
          await store.patch(story.id, patch);
        }
        _historySyncError = null;
      } catch (_) {
        _historySyncError =
            'Changes are saved on this device. Reconnect to sync this story.';
      } finally {
        _historyWrites.remove(story.id);
      }
    });
  }

  Future<void> flushHistoryWrites() async {
    await Future.wait(_historyWrites.values.toList());
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
      if (_historyCatalogCache != null) 'historyCatalog': _historyCatalogCache,
      'savedTemplates': _savedTemplates.map(
        (id, template) => MapEntry(id, template.toJson()),
      ),
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
