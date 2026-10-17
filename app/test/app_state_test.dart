import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'profile and guest sessions persist without clearing local stories',
    () async {
      final state = await AppState.load();
      expect(state.profileName, isNull);
      expect(state.isGuest, isFalse);
      expect(state.darkMode, isFalse);
      await expectLater(state.setProfile('   '), throwsArgumentError);
      await state.setProfile('  Sarnai  ');
      final story = await state.createChronicle();
      expect(state.profileName, 'Sarnai');
      final restored = await AppState.load();
      expect(restored.profileName, 'Sarnai');
      expect(restored.isGuest, isFalse);
      expect(restored.storyById(story.id)?.title, story.title);
      await restored.signOut();
      expect(restored.library, hasLength(1));
      await restored.enterGuest();
      final guest = await AppState.load();
      expect(guest.isGuest, isTrue);
      expect(guest.profileName, isNull);
      expect(guest.library, hasLength(1));
    },
  );

  test(
    'prepared selections change actual content and preserve selected voice',
    () async {
      final state = await AppState.load();
      final first = state.draftTemplate;
      await state.updateDraft(genre: 'Chronicle · tovchoo', voiceId: 'daniel');
      final selected = state.draftTemplate;
      expect(selected.id, isNot(first.id));
      expect(selected.plainText, isNot(first.plainText));
      expect(state.draft.genre, selected.genre);
      expect(state.draft.style, selected.style);
      expect(state.draft.mood, selected.mood);
      expect(state.draft.seed, selected.seed);
      final story = await state.createChronicle();
      expect(story.templateId, selected.id);
      expect(story.voiceId, 'daniel');
      expect(
        state.audioAssetFor(story),
        'assets/audio/daniel/kharkhorin-notebook.m4a',
      );
      await expectLater(
        state.updateDraft(genre: 'Unsupported'),
        throwsArgumentError,
      );
      expect(state.draftTemplate.id, selected.id);
      await state.selectSite('erdene-zuu');
      expect(state.draftTemplate.siteId, 'erdene-zuu');
      expect(state.draft.voiceId, 'daniel');
      expect(state.draft.genre, 'Legend · domog');
    },
  );

  test('voice and cover changes preserve a nondefault story preset', () async {
    final state = await AppState.load();
    await state.updateDraft(genre: 'Chronicle · tovchoo');
    final selected = state.draftTemplate;
    await state.updateDraft(voiceId: 'daniel');
    await state.updateDraft(coverPath: '/demo/chronicle-cover.jpg');
    expect(state.draftTemplate.id, selected.id);
    expect(state.draft.genre, selected.genre);
    expect(state.draft.style, selected.style);
    expect(state.draft.mood, selected.mood);
    expect(state.draft.seed, selected.seed);
    await state.clearDraftCover();
    expect(state.draftTemplate.id, selected.id);
    expect(state.draft.voiceId, 'daniel');
    final restored = await AppState.load();
    final story = await restored.createChronicle();
    expect(story.templateId, selected.id);
    expect(story.voiceId, 'daniel');
  });

  test('draft, queue, bookmarks and preferences survive relaunch', () async {
    final state = await AppState.load();
    await state.selectSite('tovkhon');
    await state.updateDraft(
      genre: 'Chronicle · tovchoo',
      voiceId: 'moira',
      coverPath: '/demo/cover.jpg',
    );
    await state.queueDraft();
    final queueId = state.queuedDrafts.single.id;
    await state.toggleSiteBookmark('tovkhon');
    await state.setDarkMode(false);
    await state.setTextScale(1.25);
    await state.setPlaybackSpeed(1.5);
    await state.setOffline(true);
    await state.setPackInstalled('tovkhon', true);
    final restored = await AppState.load();
    expect(restored.draft.siteId, 'tovkhon');
    expect(restored.draft.coverPath, '/demo/cover.jpg');
    expect(restored.draft.voiceId, 'moira');
    expect(restored.queuedDrafts.single.id, queueId);
    expect(restored.bookmarkedSiteIds, contains('tovkhon'));
    expect(restored.darkMode, isFalse);
    expect(restored.offline, isTrue);
    expect(restored.textScale, 1.25);
    expect(restored.playbackSpeed, 1.5);
    expect(restored.installedPacks, contains('tovkhon'));
    await restored.selectSite('kharkhorin');
    expect(restored.draft.coverPath, isNull);
    await restored.restoreQueuedDraft(queueId);
    expect(restored.draft.siteId, 'tovkhon');
    expect(restored.draft.genre, 'Chronicle · tovchoo');
    expect(restored.draft.coverPath, '/demo/cover.jpg');
    await restored.clearDraftCover();
    expect(restored.draft.coverPath, isNull);
    await restored.removeQueuedDraft(queueId);
    expect(restored.queuedDrafts, isEmpty);
  });

  test('branches retain narrator and reject unrelated continuation', () async {
    final state = await AppState.load();
    await state.updateDraft(voiceId: 'karen', coverPath: '/demo/tree.jpg');
    final first = await state.createChronicle();
    await state.updateDraft(voiceId: 'daniel');
    final second = await state.createChronicle(
      templateId: 'workshop',
      parentId: first.id,
    );
    final third = await state.createChronicle(
      templateId: 'steppe-return',
      parentId: second.id,
    );
    expect(second.parentId, first.id);
    expect(second.voiceId, 'karen');
    expect(third.voiceId, 'karen');
    expect(third.image, '/demo/tree.jpg');
    await expectLater(
      state.createChronicle(templateId: 'erdene-bell', parentId: third.id),
      throwsArgumentError,
    );
    expect(state.library, hasLength(3));
    await state.deleteChronicle(second.id);
    expect(state.storyById(second.id), isNull);
    expect(state.storyById(first.id), isNotNull);
    expect(state.storyById(third.id), isNotNull);
    final restored = await AppState.load();
    expect(restored.library, hasLength(2));
    expect(restored.storyById(third.id)?.voiceId, 'karen');
  });

  test(
    'concurrent progress saves finish at latest revision and reset is complete',
    () async {
      final state = await AppState.load();
      final story = await state.createChronicle();
      await state.toggleStoryBookmark(story.id);
      await Future.wait([
        state.saveProgress(story.id, .2, 1000),
        state.saveProgress(story.id, .8, 9000),
        state.setTextScale(1.3),
      ]);
      final restored = await AppState.load();
      expect(restored.storyById(story.id)?.readingProgress, .8);
      expect(restored.storyById(story.id)?.audioPositionMs, 9000);
      expect(restored.storyById(story.id)?.bookmarked, isTrue);
      expect(restored.textScale, 1.3);
      await restored.saveProgress(story.id, 2, -10);
      expect(restored.storyById(story.id)?.readingProgress, 1);
      expect(restored.storyById(story.id)?.audioPositionMs, 0);
      await restored.resetDemo();
      final clean = await AppState.load();
      expect(clean.library, isEmpty);
      expect(clean.queuedDrafts, isEmpty);
      expect(clean.installedPacks, isEmpty);
      expect(clean.bookmarkedSiteIds, isEmpty);
      expect(clean.textScale, 1);
      expect(clean.draftTemplate.id, 'silver-tree');
      expect(clean.darkMode, isFalse);
    },
  );

  test(
    'broken preferences and one malformed library record recover safely',
    () async {
      SharedPreferences.setMockInitialValues({AppState.storageKey: '{broken'});
      final clean = await AppState.load();
      expect(clean.library, isEmpty);
      final story = await clean.createChronicle();
      final preferences = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(preferences.getString(AppState.storageKey)!)
              as Map<String, dynamic>;
      (saved['library'] as List<dynamic>).add({'id': 'broken'});
      await preferences.setString(AppState.storageKey, jsonEncode(saved));
      final recovered = await AppState.load();
      expect(recovered.library, hasLength(1));
      expect(recovered.library.single.id, story.id);
    },
  );
}
