import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:ov_chronicles/history/history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CloudStore implements HistoryStore {
  _CloudStore() {
    final standard =
        jsonDecode(File('../seed/catalog.json').readAsStringSync())
            as Map<String, dynamic>;
    final history =
        jsonDecode(
              File('../seed/secret-history-english.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    catalog = {
      'sites': [...standard['sites'] as List, ...history['sites'] as List],
      'templates': [
        ...standard['templates'] as List,
        ...history['templates'] as List,
      ],
      'historicalPlaces': history['historicalPlaces'],
    };
    for (final template in catalog['templates'] as List) {
      if (template['contentKind'] == 'prepared-demo') {
        template['audioByVoice'] = {
          for (final voice in ['samantha', 'daniel', 'karen', 'moira'])
            voice: {
              'storagePath': 'catalog/audio/$voice/${template['id']}.m4a',
            },
        };
      }
    }
    (catalog['templates'] as List).first['title'] =
        'The Silver Tree from Cloud';
  }

  late final Map<String, dynamic> catalog;
  final List<Map<String, dynamic>> created = [];
  final Map<String, Map<String, Object>> progress = {};
  final List<Map<String, dynamic>> extraLibrary = [];
  final List<String> audioRequests = [];
  String owner = 'main-google-uid';
  bool catalogUnavailable = false;

  @override
  String get uid => owner;
  @override
  Future<Map<String, dynamic>> loadCatalog() async {
    if (catalogUnavailable) throw StateError('offline');
    return catalog;
  }

  @override
  Future<List<Map<String, dynamic>>> loadLibrary() async => [
    for (final snapshot in created)
      {
        'chronicle': snapshot,
        'library': progress[snapshot['id']] ?? <String, Object>{},
      },
    ...extraLibrary,
  ];
  @override
  Future<Map<String, dynamic>> create({
    required String requestId,
    required String templateId,
    required String voiceId,
    String? parentId,
  }) async {
    final template = (catalog['templates'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['id'] == templateId);
    final snapshot = <String, dynamic>{
      ...template,
      'id': 'cloud-story-${created.length + 1}',
      'uid': uid,
      'templateId': templateId,
      'voiceId': voiceId,
      'audioPath': 'catalog/audio/$voiceId/$templateId.m4a',
      'status': 'ready',
      'parentId': ?parentId,
      'createdAt': DateTime.utc(2026, 10, 18).toIso8601String(),
    };
    created.add(snapshot);
    return snapshot;
  }

  @override
  Future<void> patch(String id, Map<String, Object> values) async {
    progress[id] = {...?progress[id], ...values};
  }

  @override
  Future<void> delete(String id) async =>
      created.removeWhere((s) => s['id'] == id);
  @override
  Future<String> audioUrl(String storagePath) async {
    audioRequests.add(storagePath);
    return 'https://example.test/$storagePath';
  }
}

Future<AppState> _cloud() => AppState.loadForAccount(
  uid: 'main-google-uid',
  displayName: 'Traveler',
  environment: 'live',
  projectId: 'ov-ai-5ae61',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Kharkhorin and chapter paths create cloud snapshots using the selected narrator',
    () async {
      final store = _CloudStore();
      final state = await _cloud();
      await state.loadHistoricalCatalog(store: store);
      expect(state.historyCatalogError, isNull);
      expect(state.sites, hasLength(5));
      expect(state.templates, hasLength(17));
      expect(
        state.defaultTemplateForSite('kharkhorin').title,
        'The Silver Tree from Cloud',
      );
      await state.selectSite('kharkhorin');
      await state.updateDraft(voiceId: 'daniel');
      final first = await state.createChronicle(templateId: 'silver-tree');
      final next = await state.createChronicle(
        templateId: 'workshop',
        parentId: first.id,
      );
      expect(store.created, hasLength(2));
      expect(first.isRemote, isTrue);
      expect(first.remoteUid, 'main-google-uid');
      expect(first.title, 'The Silver Tree from Cloud');
      expect(next.parentId, first.id);
      expect(next.voiceId, 'daniel');
      await state.saveProgress(first.id, .4, 12000);
      await state.toggleStoryBookmark(first.id);
      await state.flushHistoryWrites();
      expect(store.progress[first.id]!['audioPositionMs'], 12000);
      expect(
        await state.remoteAudioUriFor(first),
        Uri.parse('https://example.test/catalog/audio/daniel/silver-tree.m4a'),
      );

      final restored = await _cloud();
      await restored.loadHistoricalCatalog(store: store);
      expect(restored.library, hasLength(2));
      expect(restored.storyById(first.id)!.audioPositionMs, 12000);
      expect(restored.storyById(first.id)!.bookmarked, isTrue);
      expect(restored.storyById(next.id)!.parentId, first.id);
      expect(
        restored.templateFor(restored.storyById(first.id)!).isHistorical,
        isFalse,
      );
      await restored.deleteChronicle(next.id);
      expect(store.created, hasLength(1));
    },
  );

  test(
    'cloud library accepts both content kinds and skips foreign or deleted snapshots',
    () async {
      final store = _CloudStore();
      final state = await _cloud();
      await state.loadHistoricalCatalog(store: store);
      final standard = await state.createChronicle(templateId: 'silver-tree');
      await state.createChronicle(templateId: 'onon-child-en');
      store.extraLibrary.addAll([
        {
          'chronicle': {
            ...store.created.first,
            'id': 'foreign',
            'uid': 'another-user',
          },
          'library': <String, Object>{},
        },
        {
          'chronicle': {
            ...store.created.first,
            'id': 'deleted',
            'status': 'deleted',
          },
          'library': <String, Object>{},
        },
      ]);
      final restored = await _cloud();
      await restored.loadHistoricalCatalog(store: store);
      expect(restored.library, hasLength(2));
      expect(restored.storyById(standard.id), isNotNull);
      expect(restored.storyById('foreign'), isNull);
      expect(restored.storyById('deleted'), isNull);
    },
  );

  test(
    'cloud guests read bundled stories locally without creating a cloud or anonymous chronicle',
    () async {
      final store = _CloudStore()..owner = '';
      final state = await AppState.load(projectId: 'ov-ai-5ae61');
      await state.loadHistoricalCatalog(store: store);
      expect(state.sites, hasLength(5));
      final story = await state.createChronicle(templateId: 'silver-tree');
      expect(store.created, isEmpty);
      expect(story.isRemote, isFalse);
      expect(state.library.single.id, story.id);
    },
  );

  test(
    'cached cloud catalog and bundled narration remain usable offline without local creation fallback',
    () async {
      final store = _CloudStore();
      final state = await _cloud();
      await state.loadHistoricalCatalog(store: store);
      final saved = await state.createChronicle(templateId: 'silver-tree');
      final cached = await _cloud();
      store.catalogUnavailable = true;
      await cached.loadHistoricalCatalog(store: store);
      expect(cached.historyCatalogError, isNotNull);
      expect(cached.sites, hasLength(5));
      expect(
        cached.templateFor(cached.storyById(saved.id)!).title,
        'The Silver Tree from Cloud',
      );
      await cached.setOffline(true);
      expect(
        await cached.remoteAudioUriFor(cached.storyById(saved.id)!),
        isNull,
      );
      expect(
        cached.audioAssetFor(cached.storyById(saved.id)!),
        'assets/audio/samantha/silver-tree.m4a',
      );
      await expectLater(
        cached.createChronicle(templateId: 'silver-tree'),
        throwsStateError,
      );
      expect(store.created, hasLength(1));
    },
  );
}
