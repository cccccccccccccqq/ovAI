import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:ov_chronicles/core/audio_controller.dart';
import 'package:ov_chronicles/history/history_store.dart';
import 'package:ov_chronicles/main.dart';
import 'package:ov_chronicles/screens/discovery_screens.dart';
import 'package:ov_chronicles/screens/inscribe_screens.dart';
import 'package:ov_chronicles/screens/reader_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PreparedHistoryStore implements HistoryStore {
  _PreparedHistoryStore()
    : catalog =
          jsonDecode(
                File('../seed/secret-history-english.json').readAsStringSync(),
              )
              as Map<String, dynamic>;

  final Map<String, dynamic> catalog;
  final List<Map<String, dynamic>> created = [];
  final List<String> requestedAudio = [];
  final Map<String, Map<String, Object>> progress = {};

  @override
  String get uid => 'history-flow-traveller';

  @override
  Future<Map<String, dynamic>> loadCatalog() async => catalog;

  @override
  Future<List<Map<String, dynamic>>> loadLibrary() async => created
      .map(
        (snapshot) => <String, dynamic>{
          'chronicle': snapshot,
          'library': progress[snapshot['id']] ?? <String, Object>{},
        },
      )
      .toList();

  @override
  Future<Map<String, dynamic>> create({
    required String requestId,
    required String templateId,
    required String voiceId,
    String? parentId,
  }) async {
    final template = (catalog['templates'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['id'] == templateId);
    final audio = (template['audioByVoice'] as Map)[voiceId] as Map;
    final snapshot = <String, dynamic>{
      ...template,
      'id': 'saved-history-${created.length + 1}',
      'uid': uid,
      'status': 'ready',
      'templateId': templateId,
      'voiceId': voiceId,
      'audioPath': audio['storagePath'],
      'parentId': ?parentId,
      'createdAt': DateTime(2026, 10, 17).toIso8601String(),
    };
    created.add(snapshot);
    return snapshot;
  }

  @override
  Future<void> patch(String id, Map<String, Object> values) async {
    progress[id] = {...?progress[id], ...values};
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<String> audioUrl(String storagePath) async {
    requestedAudio.add(storagePath);
    return 'https://example.test/$storagePath';
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _mockAudio() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.audio_session'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.just_audio.methods'),
    (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'] as String;
        messenger.setMockMethodCallHandler(
          MethodChannel('com.ryanheise.just_audio.methods.$id'),
          (call) async {
            if (call.method == 'load') {
              throw PlatformException(code: 'no_test_decoder');
            }
            return <String, dynamic>{};
          },
        );
        for (final kind in ['events', 'data']) {
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.$kind.$id'),
            (_) async => null,
          );
        }
      }
      return <String, dynamic>{};
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockAudio();
  });

  testWidgets(
    'English Onon uses the shared place, tone, voice and chapter path',
    (tester) async {
      _phone(tester);
      final store = _PreparedHistoryStore();
      final state = await AppState.load();
      await state.loadHistoricalCatalog(store: store);
      await state.setProfile('Saran');
      await state.selectSite('onon');
      await state.setOffline(true);
      await tester.pumpWidget(OvApp(state: state));
      await tester.pumpAndSettle();
      expect(find.byType(SteppeScreen), findsOneWidget);
      expect(find.text('Inscribe this place'), findsOneWidget);
      expect(find.text('Read a prepared story'), findsOneWidget);
      expect(find.text('Ононы эрэгт мэндэлсэн хүү'), findsNothing);
      expect(find.text(state.selectedSite.locationNote!), findsOneWidget);

      await _tap(tester, find.text('Inscribe'));
      expect(find.byType(PlaceScreen), findsOneWidget);
      expect(state.draft.siteId, 'onon');
      await _tap(tester, find.text('Next: set the tone'));
      expect(find.byType(ToneScreen), findsOneWidget);
      await _tap(tester, find.text('Lyrical'));
      expect(state.draftTemplate.id, 'onon-child-lyrical-en');
      await _tap(tester, find.text('Next: choose a voice'));
      expect(find.byType(VoiceScreen), findsOneWidget);
      for (final voice in state.voices) {
        expect(find.text(voice.name), findsOneWidget);
      }
      await _tap(tester, find.text('Daniel'));
      await state.setOffline(false);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Prepare my chronicle'));
      for (var step = 0; step < 4; step++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('Secret History · English synopsis'), findsOneWidget);
      expect(find.text('Curated demo · original fiction'), findsNothing);
      final first = state.library.single;
      expect(first.templateId, 'onon-child-lyrical-en');
      expect(first.voiceId, 'daniel');
      expect(store.created.single['language'], 'en');

      final router = GoRouter.of(tester.element(find.byType(ReaderScreen)));
      router.go('/reader/${first.id}/end');
      await tester.pumpAndSettle();
      expect(find.byType(ReaderEndScreen), findsOneWidget);
      expect(find.text('Choose your path'), findsOneWidget);
      await _tap(
        tester,
        find.text(state.templateById('hoelun-family-en').title),
      );
      expect(find.byType(ReaderScreen), findsOneWidget);
      final next = state.library.firstWhere(
        (story) => story.parentId == first.id,
      );
      expect(next.templateId, 'hoelun-family-en');
      expect(next.voiceId, 'daniel');
      expect(state.templateFor(next).chapter, 2);
      expect(store.created, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  test(
    'historical snapshots, narrator, parent and server progress survive reload',
    () async {
      final store = _PreparedHistoryStore();
      final state = await AppState.load();
      await state.loadHistoricalCatalog(store: store);
      await state.selectSite('onon');
      await state.updateDraft(style: 'Lyrical', voiceId: 'karen');
      final first = await state.createChronicle();
      final next = await state.createChronicle(
        templateId: 'hoelun-family-en',
        parentId: first.id,
      );
      await state.saveProgress(first.id, .45, 92000);
      await state.toggleStoryBookmark(first.id);
      await state.flushHistoryWrites();
      final cached = await AppState.load();
      expect(cached.library, hasLength(2));
      expect(cached.storyById(first.id)!.isRemote, true);
      expect(cached.storyById(next.id)!.parentId, first.id);
      expect(
        cached.templateFor(cached.storyById(first.id)!).isHistorical,
        true,
      );
      expect(cached.storyById(first.id)!.audioPositionMs, 92000);
      await cached.loadHistoricalCatalog(store: store);
      expect(cached.historyCatalogError, isNull);
      expect(cached.storyById(first.id)!.bookmarked, true);
      expect(cached.storyById(first.id)!.audioPositionMs, 92000);
      expect(cached.storyById(next.id)!.voiceId, 'karen');
      expect(
        await cached.remoteAudioUriFor(cached.storyById(first.id)!),
        Uri.parse(
          'https://example.test/catalog/audio/karen/onon-child-lyrical-en.m4a',
        ),
      );
    },
  );

  test(
    'failed remote audio loading cannot erase the saved resume position',
    () async {
      final store = _PreparedHistoryStore();
      final state = await AppState.load();
      await state.loadHistoricalCatalog(store: store);
      await state.selectSite('onon');
      final first = await state.createChronicle();
      await state.saveProgress(first.id, .3, 92000);
      final audio = AudioController(state);
      await audio.playStory(state.storyById(first.id)!);
      expect(audio.error, isNotNull);
      await audio.stop();
      final cached = await AppState.load();
      expect(cached.storyById(first.id)!.audioPositionMs, 92000);
      expect(store.progress[first.id]!['audioPositionMs'], 92000);
      audio.dispose();
    },
  );

  testWidgets('the old history link opens the standard English reader', (
    tester,
  ) async {
    _phone(tester);
    final store = _PreparedHistoryStore();
    final state = await AppState.load();
    await state.loadHistoricalCatalog(store: store);
    await state.setProfile('Saran');
    await tester.pumpWidget(
      OvApp(state: state, initialLocation: '/history/onon-child'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(state.library.single.templateId, 'onon-child-en');
    expect(state.selectedSite.id, 'onon');
    expect(find.text('Secret History · English synopsis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
