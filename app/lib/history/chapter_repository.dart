import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../backend/backend_configuration.dart';
import '../backend/cloud_firebase.dart';
import 'chapter_models.dart';
import 'chapter_web_bootstrap.dart';

/// Cloud data uses the main social account. Explicit emulator mode keeps the
/// historical pilot's anonymous test accounts isolated from cloud identities.
class ChapterRepository {
  ChapterRepository._(this.app, {required this.session});
  final BackendSession session;
  final FirebaseApp app;
  static final Map<String, Future<ChapterRepository>> _instances = {};
  static final Set<String> _servicesConfigured = {};
  static const projectId = 'demo-ov-chronicles';
  static const _host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const _timeout = Duration(seconds: 12);

  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: app);
  FirebaseFirestore get _db => FirebaseFirestore.instanceFor(app: app);
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(app: app, region: 'asia-northeast1');
  FirebaseStorage get _storage => FirebaseStorage.instanceFor(app: app);

  static Future<ChapterRepository> connect({
    String appName = 'ov-history-local',
  }) async {
    if (!BackendConfiguration.current.isEmulator) {
      final app = await CloudFirebase.initialize();
      final user = FirebaseAuth.instanceFor(app: app).currentUser;
      return ChapterRepository._(
        app,
        session: BackendSession(
          uid: user?.uid,
          isAnonymous: user?.isAnonymous ?? true,
          isEmulator: false,
        ),
      );
    }
    try {
      return await (_instances[appName] ??= _connect(appName));
    } catch (_) {
      _instances.remove(appName);
      rethrow;
    }
  }

  static Future<ChapterRepository> _connect(String appName) async {
    final existing = Firebase.apps.where((app) => app.name == appName).toList();
    final isNew = existing.isEmpty;
    await prepareChapterWebEmulator(host: _host, appName: appName);
    final options = FirebaseOptions(
      apiKey: 'ADemoProjectApiKey000000000000000000000',
      appId:
          '1:1:${kIsWeb
              ? 'web'
              : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'ios'}:1',
      messagingSenderId: '1',
      projectId: projectId,
      authDomain: '$projectId.firebaseapp.com',
      storageBucket: '$projectId.appspot.com',
      iosBundleId: 'mn.ov.ovChronicles',
    );
    // The native Firestore platform factory requires a default Core app even
    // when all reads use an explicitly named app. Core initialization does not
    // sign in or start any service on that default app.
    if (!kIsWeb && !Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
      await Firebase.initializeApp(options: options);
    }
    // The web bootstrap has already created this public SDK app. Wrap it
    // rather than initializing it twice (optional JS option keys differ).
    final app = kIsWeb
        ? Firebase.app(appName)
        : isNew
        ? await Firebase.initializeApp(name: appName, options: options)
        : existing.single;
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'asia-northeast1',
    );
    final storage = FirebaseStorage.instanceFor(app: app);
    if (!_servicesConfigured.contains(appName)) {
      // Web Auth is already connected synchronously by the bootstrap, before
      // persisted-user restoration. Reconfiguring after restore is too late.
      if (!kIsWeb) {
        await auth.useAuthEmulator(_host, 9099, automaticHostMapping: false);
      }
      db.settings = const Settings(persistenceEnabled: false);
      db.useFirestoreEmulator(_host, 18080, automaticHostMapping: false);
      functions.useFunctionsEmulator(_host, 5001, automaticHostMapping: false);
      await storage.useStorageEmulator(
        _host,
        9199,
        automaticHostMapping: false,
      );
      _servicesConfigured.add(appName);
    }
    await auth.authStateChanges().first.timeout(_timeout);
    if (auth.currentUser == null) {
      await auth.signInAnonymously().timeout(_timeout);
    }
    final user = auth.currentUser!;
    return ChapterRepository._(
      app,
      session: BackendSession(
        uid: user.uid,
        isAnonymous: user.isAnonymous,
        isEmulator: true,
      ),
    );
  }

  bool get canAccessPrivateData => session.canAccessPrivateData;

  String get uid =>
      session.canAccessPrivateData && _auth.currentUser?.uid == session.uid
      ? session.uid!
      : '';

  void assertSession() {
    if (_auth.currentUser?.uid != session.uid) {
      throw StateError('The active account changed. Reopen your library.');
    }
  }

  Future<String> preparePrivateAccess() async {
    final owner = session.requireOwner(currentUid: _auth.currentUser?.uid);
    if (!session.isEmulator) {
      await CloudFirebase.requireAppCheck(app).timeout(_timeout);
    }
    session.requireOwner(currentUid: _auth.currentUser?.uid);
    return owner;
  }

  Future<ChapterBundle> load(String chapterId) async {
    final startingUid = uid;
    const server = GetOptions(source: Source.server);
    final snapshot = await _db
        .collection('chapters')
        .doc(chapterId)
        .get(server)
        .timeout(_timeout);
    if (!snapshot.exists) throw StateError('Chapter has not been imported.');
    final chapter = HistoricalChapter.fromDocument(
      snapshot.id,
      snapshot.data()!,
    );
    final placeIds = chapter.scenes.map((scene) => scene.placeId).toSet();
    final places = await Future.wait(
      placeIds.map((id) async {
        final doc = await _db
            .collection('historicalPlaces')
            .doc(id)
            .get(server)
            .timeout(_timeout);
        if (!doc.exists) throw StateError('Chapter map region is missing.');
        return HistoricalPlace.fromDocument(doc.id, doc.data()!);
      }),
    );
    Map<String, dynamic> progressData = {};
    if (canAccessPrivateData) {
      final progressDoc = await _db
          .collection('users')
          .doc(startingUid)
          .collection('chapterProgress')
          .doc(chapterId)
          .get(server)
          .timeout(_timeout);
      progressData = progressDoc.data() ?? {};
    }
    assertSession();
    final progress = ChapterProgress.fromMap(progressData).forChapter(chapter);
    return ChapterBundle(
      chapter: chapter,
      places: {for (final place in places) place.id: place},
      progress: progress,
      uid: uid,
    );
  }

  Future<String> audioUrl(HistoricalChapter chapter) =>
      _storage.ref(chapter.audioPath).getDownloadURL().timeout(_timeout);

  Future<ChapterProgress> save(
    HistoricalChapter chapter, {
    required int audioPositionMs,
    required bool bookmarked,
    required bool completed,
  }) async {
    final startingUid = await preparePrivateAccess();
    final result = await _functions
        .httpsCallable('patchChapterProgress')
        .call<dynamic>({
          'chapterId': chapter.id,
          'contentVersion': chapter.contentVersion,
          'audioPositionMs': audioPositionMs.clamp(0, chapter.durationMs),
          'bookmarked': bookmarked,
          'completed': completed,
        })
        .timeout(_timeout);
    if (startingUid != uid) throw StateError('The active account changed.');
    return ChapterProgress.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}
