import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'chapter_repository.dart';

/// Shared Kharkhorin UI uses this boundary for real historical catalog records.
/// Fake stores in tests exercise the same state transitions without networking.
abstract interface class HistoryStore {
  String get uid;
  Future<Map<String, dynamic>> loadCatalog();
  Future<List<Map<String, dynamic>>> loadLibrary();
  Future<Map<String, dynamic>> create({
    required String requestId,
    required String templateId,
    required String voiceId,
    String? parentId,
  });
  Future<void> patch(String id, Map<String, Object> values);
  Future<void> delete(String id);
  Future<String> audioUrl(String storagePath);
}

class FirebaseHistoryStore implements HistoryStore {
  FirebaseHistoryStore._(this.connection);
  final ChapterRepository connection;
  static const _timeout = Duration(seconds: 15);
  FirebaseFirestore get _db =>
      FirebaseFirestore.instanceFor(app: connection.app);
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    app: connection.app,
    region: 'asia-northeast1',
  );
  FirebaseStorage get _storage =>
      FirebaseStorage.instanceFor(app: connection.app);
  @override
  String get uid => connection.uid;

  static Future<FirebaseHistoryStore> connect(String scope) async {
    // Full reversible encoding, with no truncation or identity collisions.
    final suffix = base64Url.encode(utf8.encode(scope)).replaceAll('=', '');
    final name = scope == 'ov.prototype.state.v1'
        ? 'ov-history-local'
        : 'ov-history-$suffix';
    return FirebaseHistoryStore._(
      await ChapterRepository.connect(appName: name),
    );
  }

  @override
  Future<Map<String, dynamic>> loadCatalog() async {
    if (!connection.session.isEmulator) return _loadAllPreparedCatalog();
    const server = GetOptions(source: Source.server);
    final series = await _db
        .collection('series')
        .doc('temujin-childhood-en')
        .get(server)
        .timeout(_timeout);
    if (!series.exists || series.data()?['status'] != 'published') {
      throw StateError('Import the English Onon series first.');
    }
    final site = await _db
        .collection('sites')
        .doc('onon')
        .get(server)
        .timeout(_timeout);
    if (!site.exists) throw StateError('The Onon place has not been imported.');
    final published = await _db
        .collection('storyTemplates')
        .where('siteId', isEqualTo: 'onon')
        .where('status', isEqualTo: 'published')
        .get(server)
        .timeout(_timeout);
    final templates = published.docs.map((snapshot) {
      if (snapshot.data()['language'] != 'en' ||
          snapshot.data()['contentKind'] != 'historical-synopsis') {
        throw StateError('An English prepared chapter is unavailable.');
      }
      return <String, dynamic>{'id': snapshot.id, ...snapshot.data()};
    }).toList();
    final canonical = List<String>.from(series.data()!['chapterIds'] as List);
    templates.sort((a, b) {
      final ai = canonical.indexOf(a['id'] as String),
          bi = canonical.indexOf(b['id'] as String);
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
    if (templates.length < canonical.length) {
      throw StateError('Some chapters have not been imported.');
    }
    final placeIds = <String>{};
    for (final template in templates) {
      for (final scene in template['scenes'] as List? ?? []) {
        placeIds.add((scene as Map)['placeId'] as String);
      }
    }
    final places = await Future.wait(
      placeIds.map((id) async {
        final snapshot = await _db
            .collection('historicalPlaces')
            .doc(id)
            .get(server)
            .timeout(_timeout);
        if (!snapshot.exists) {
          throw StateError('Historical context is unavailable.');
        }
        return {'id': snapshot.id, ...snapshot.data()!};
      }),
    );
    connection.assertSession();
    return {
      'sites': [
        {'id': site.id, ...site.data()!},
      ],
      'templates': templates,
      'historicalPlaces': places,
    };
  }

  Future<Map<String, dynamic>> _loadAllPreparedCatalog() async {
    const server = GetOptions(source: Source.server);
    final results = await Future.wait([
      _db
          .collection('sites')
          .where('status', isEqualTo: 'published')
          .get(server)
          .timeout(_timeout),
      _db
          .collection('storyTemplates')
          .where('status', isEqualTo: 'published')
          .get(server)
          .timeout(_timeout),
    ]);
    final sites = results[0].docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
    final siteIds = sites.map((site) => site['id']).toSet();
    final templates = results[1].docs
        .where(
          (doc) =>
              siteIds.contains(doc.data()['siteId']) &&
              doc.data()['language'] == 'en' &&
              const {
                'prepared-demo',
                'historical-synopsis',
              }.contains(doc.data()['contentKind']),
        )
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
    if (sites.isEmpty || templates.isEmpty) {
      throw StateError('The published story catalog is unavailable.');
    }
    templates.sort((a, b) {
      final byChapter = (a['chapter'] as num).compareTo(b['chapter'] as num);
      return byChapter == 0
          ? (a['id'] as String).compareTo(b['id'] as String)
          : byChapter;
    });
    final placeIds = <String>{};
    for (final template in templates) {
      for (final scene in template['scenes'] as List? ?? []) {
        placeIds.add((scene as Map)['placeId'] as String);
      }
    }
    final places = await Future.wait(
      placeIds.map((id) async {
        final snapshot = await _db
            .collection('historicalPlaces')
            .doc(id)
            .get(server)
            .timeout(_timeout);
        if (!snapshot.exists || snapshot.data()?['status'] != 'published') {
          throw StateError('Historical context is unavailable.');
        }
        return <String, dynamic>{'id': snapshot.id, ...snapshot.data()!};
      }),
    );
    connection.assertSession();
    return {'sites': sites, 'templates': templates, 'historicalPlaces': places};
  }

  @override
  Future<List<Map<String, dynamic>>> loadLibrary() async {
    connection.assertSession();
    if (!connection.canAccessPrivateData) return [];
    final owner = uid;
    final library = await _db
        .collection('users')
        .doc(owner)
        .collection('library')
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    final snapshots = await Future.wait(
      library.docs
          .where(
            (d) =>
                !connection.session.isEmulator ||
                d.data()['contentKind'] == 'historical-synopsis',
          )
          .map((item) async {
            final snapshot = await _db
                .collection('chronicles')
                .doc(item.id)
                .get(const GetOptions(source: Source.server))
                .timeout(_timeout);
            if (!snapshot.exists ||
                snapshot.data()?['uid'] != owner ||
                snapshot.data()?['status'] != 'ready') {
              return null;
            }
            return {
              'chronicle': {'id': snapshot.id, ...snapshot.data()!},
              'library': item.data(),
            };
          }),
    );
    if (uid != owner) throw StateError('The active account changed.');
    return snapshots.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object> data,
  ) async {
    final owner = await connection.preparePrivateAccess();
    final result = await _functions
        .httpsCallable(name)
        .call<dynamic>(data)
        .timeout(_timeout);
    if (uid != owner) throw StateError('The active account changed.');
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> create({
    required String requestId,
    required String templateId,
    required String voiceId,
    String? parentId,
  }) async {
    final result = await _call('createPreparedChronicle', {
      'requestId': requestId,
      'templateId': templateId,
      'voiceId': voiceId,
      'parentId': ?parentId,
    });
    final id = result['chronicleId'] as String;
    final snapshot = await _db
        .collection('chronicles')
        .doc(id)
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    if (!snapshot.exists || snapshot.data()?['uid'] != uid) {
      throw StateError('The saved story is unavailable.');
    }
    return {'id': id, ...snapshot.data()!};
  }

  @override
  Future<void> patch(String id, Map<String, Object> values) async {
    await _call('patchLibraryItem', {'chronicleId': id, ...values});
  }

  @override
  Future<void> delete(String id) async {
    await _call('deleteChronicle', {'chronicleId': id});
  }

  @override
  Future<String> audioUrl(String storagePath) {
    if (!storagePath.startsWith('catalog/audio/') ||
        storagePath.contains('..')) {
      throw StateError('Expected published audio.');
    }
    return _storage.ref(storagePath).getDownloadURL().timeout(_timeout);
  }
}
