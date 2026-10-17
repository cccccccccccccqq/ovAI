import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'backend_contracts.dart';
import 'backend_models.dart';

export 'backend_contracts.dart';
export 'backend_models.dart';

/// Explicit Firebase connection for the next application data layer.
///
/// Nothing initializes or signs in just by importing this file. The existing
/// local prototype and its saved library remain independent until migrated.
class FirebaseBackend {
  FirebaseBackend._(this.app, {required this.isEmulator})
    : auth = FirebaseAuth.instanceFor(app: app),
      firestore = FirebaseFirestore.instanceFor(app: app),
      functions = FirebaseFunctions.instanceFor(app: app, region: region),
      storage = FirebaseStorage.instanceFor(app: app);

  static const region = 'asia-northeast1';
  static const emulatorProjectId = 'demo-ov-chronicles';

  final FirebaseApp app;
  final bool isEmulator;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseStorage storage;

  /// Uses a demo project and routes every service to a local emulator.
  ///
  /// Web/iOS simulator use 127.0.0.1. Pass 10.0.2.2 explicitly for Android's
  /// emulator, or the development machine's LAN address for a physical phone.
  /// Initialize once per app session, before reading any Firebase service.
  static Future<FirebaseBackend> initializeEmulators({
    String host = '127.0.0.1',
    int authPort = 9099,
    int firestorePort = 18080,
    int functionsPort = 5001,
    int storagePort = 9199,
  }) async {
    if (host.trim().isEmpty || host.contains('://') || host.contains('/')) {
      throw ArgumentError.value(host, 'host', 'Pass a hostname or IP address.');
    }
    for (final port in [authPort, firestorePort, functionsPort, storagePort]) {
      if (port < 1 || port > 65535) {
        throw ArgumentError.value(port, 'port', 'Use 1–65535.');
      }
    }
    const name = 'ov-emulator';
    _requireUninitialized(name);
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
            TargetPlatform.android => 'android',
            _ => 'web',
          };
    final app = await Firebase.initializeApp(
      name: name,
      options: FirebaseOptions(
        apiKey: 'ADemoProjectApiKey000000000000000000000',
        appId: '1:1:$platform:1',
        messagingSenderId: '1',
        projectId: emulatorProjectId,
        authDomain: '$emulatorProjectId.firebaseapp.com',
        storageBucket: '$emulatorProjectId.appspot.com',
        iosBundleId: 'mn.ov.ovChronicles',
      ),
    );
    final backend = FirebaseBackend._(app, isEmulator: true);
    try {
      await backend.auth.useAuthEmulator(
        host,
        authPort,
        automaticHostMapping: false,
      );
      backend.firestore.settings = const Settings(persistenceEnabled: false);
      backend.firestore.useFirestoreEmulator(
        host,
        firestorePort,
        automaticHostMapping: false,
      );
      backend.functions.useFunctionsEmulator(
        host,
        functionsPort,
        automaticHostMapping: false,
      );
      await backend.storage.useStorageEmulator(
        host,
        storagePort,
        automaticHostMapping: false,
      );
      return backend;
    } catch (_) {
      await app.delete();
      rethrow;
    }
  }

  /// Requires options generated for the real registered Firebase application.
  /// No credentials or fallback project are embedded in this client.
  static Future<FirebaseBackend> initializeLive({
    required FirebaseOptions options,
    required Future<void> Function(FirebaseApp app) configureAppCheck,
    String appName = 'ov-live',
  }) async {
    if (options.projectId.startsWith('demo-')) {
      throw ArgumentError('Use initializeEmulators for demo projects.');
    }
    if (options.storageBucket == null || options.storageBucket!.isEmpty) {
      throw ArgumentError('FirebaseOptions.storageBucket is required.');
    }
    _requireUninitialized(appName);
    final app = await Firebase.initializeApp(name: appName, options: options);
    try {
      // Configure the provider registered for this platform/project before any
      // callable can run. Emulator initialization intentionally never does this.
      await configureAppCheck(app);
      return FirebaseBackend._(app, isEmulator: false);
    } catch (_) {
      await app.delete();
      rethrow;
    }
  }

  static void _requireUninitialized(String name) {
    if (Firebase.apps.any((app) => app.name == name)) {
      throw StateError(
        'Firebase app "$name" already exists. Reuse its backend.',
      );
    }
  }

  Stream<User?> authStateChanges() => auth.authStateChanges();

  /// Creates an anonymous account only when the caller explicitly requests it.
  Future<UserCredential> signInAnonymously() => auth.signInAnonymously();

  Future<void> signOut() => auth.signOut();

  String _requireUid() {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before accessing private data.');
    return uid;
  }

  void _requireSameUser(String uid) {
    if (_requireUid() != uid) {
      throw StateError(
        'Authentication changed; recreate this private subscription.',
      );
    }
  }

  /// Subscribe after sign-in; cancel private subscriptions when auth changes.
  Stream<BackendProfile?> watchProfile() {
    final uid = _requireUid();
    return firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      _requireSameUser(uid);
      final data = snapshot.data();
      return data == null
          ? null
          : BackendProfile.fromDocument(snapshot.id, data);
    });
  }

  Stream<List<BackendSite>> watchSites() => firestore
      .collection('sites')
      .where('status', isEqualTo: 'published')
      .snapshots()
      .map(
        (snapshot) => List.unmodifiable(
          snapshot.docs.map(
            (doc) => BackendSite.fromDocument(doc.id, doc.data()),
          ),
        ),
      );

  Stream<List<BackendStoryTemplate>> watchPublishedTemplates() => firestore
      .collection('storyTemplates')
      .where('status', isEqualTo: 'published')
      .snapshots()
      .map(
        (snapshot) => List.unmodifiable(
          snapshot.docs.map(
            (doc) => BackendStoryTemplate.fromDocument(doc.id, doc.data()),
          ),
        ),
      );

  Stream<List<BackendLibraryItem>> watchLibrary() {
    final uid = _requireUid();
    return firestore
        .collection('users')
        .doc(uid)
        .collection('library')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          _requireSameUser(uid);
          return List.unmodifiable(
            snapshot.docs.map(
              (doc) => BackendLibraryItem.fromDocument(doc.id, doc.data()),
            ),
          );
        });
  }

  /// Deleted documents are denied by the server rules. Handle permission errors
  /// and the delete callable's tombstone result by clearing the private reader.
  Stream<BackendChronicle?> watchChronicle(String chronicleId) {
    validateBackendId(chronicleId, 'chronicleId');
    final uid = _requireUid();
    return firestore.collection('chronicles').doc(chronicleId).snapshots().map((
      snapshot,
    ) {
      _requireSameUser(uid);
      final data = snapshot.data();
      if (data == null) return null;
      final chronicle = BackendChronicle.fromDocument(snapshot.id, data);
      if (chronicle.uid != uid) {
        throw StateError('Chronicle belongs to another user.');
      }
      return chronicle;
    });
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object> data,
  ) async {
    final uid = _requireUid();
    final result = await functions.httpsCallable(name).call<dynamic>(data);
    _requireSameUser(uid);
    return requireObject(result.data, '$name response');
  }

  Future<EnsureProfileResult> ensureProfile(
    EnsureProfileRequest request,
  ) async => EnsureProfileResult.fromJson(
    await _call('ensureProfile', request.toJson()),
  );

  Future<CreatePreparedChronicleResult> createPreparedChronicle(
    CreatePreparedChronicleRequest request,
  ) async => CreatePreparedChronicleResult.fromJson(
    await _call('createPreparedChronicle', request.toJson()),
  );

  Future<ChronicleMutationResult> patchLibraryItem(
    PatchLibraryItemRequest request,
  ) async => ChronicleMutationResult.fromJson(
    await _call('patchLibraryItem', request.toJson()),
  );

  Future<ChronicleMutationResult> deleteChronicle(String chronicleId) async {
    validateBackendId(chronicleId, 'chronicleId');
    return ChronicleMutationResult.fromJson(
      await _call('deleteChronicle', {'chronicleId': chronicleId}),
    );
  }

  /// Authenticated SDK reference, never a persistent bearer download URL.
  ///
  /// Use Reference.getData(maxBytes) or native Reference.writeToFile to obtain
  /// authorized audio. Private audio needs an authenticated fetch/cache adapter
  /// before it is handed to just_audio. Do not persist getDownloadURL tokens.
  Reference? storageAudioReference(BackendChronicle chronicle) {
    final uid = _requireUid();
    if (chronicle.uid != uid) {
      throw StateError('Chronicle belongs to another user.');
    }
    if (chronicle.status != BackendChronicleStatus.ready ||
        chronicle.audioStatus != BackendAudioStatus.ready) {
      return null;
    }
    final path = chronicle.audioPath;
    if (path == null) return null;
    final segments = path.split('/');
    if (segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        ) ||
        path.contains('://') ||
        path.contains('\\')) {
      throw FormatException(
        'Audio path must be a relative Storage object path.',
      );
    }
    final publicAudio = path.startsWith('catalog/audio/');
    final privateAudio =
        segments.length == 4 &&
        segments[0] == 'chronicles' &&
        segments[1] == uid &&
        segments[2] == chronicle.id;
    if (!publicAudio && !privateAudio) {
      throw FormatException(
        'Audio path is outside this chronicle or the public catalog.',
      );
    }
    return storage.ref(path);
  }
}
