import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _account(
  String uid, {
  String name = 'Signed-in user',
  String environment = 'emulator',
}) => AppState.loadForAccount(
  uid: uid,
  displayName: name,
  environment: environment,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'account sessions neither import nor change the legacy guest state',
    () async {
      final guest = await AppState.load();
      await guest.enterGuest();
      final guestStory = await guest.createChronicle();
      await guest.toggleSiteBookmark('kharkhorin');
      await guest.setTextScale(1.3);
      final preferences = await SharedPreferences.getInstance();
      final original = preferences.getString(AppState.storageKey);

      final account = await _account('account-a', name: 'Sarnai');
      expect(account.profileName, 'Sarnai');
      expect(account.isGuest, isFalse);
      expect(account.library, isEmpty);
      expect(account.bookmarkedSiteIds, isEmpty);
      expect(account.textScale, 1);
      await account.createChronicle();
      await account.setDarkMode(true);
      await account.resetDemo();

      expect(preferences.getString(AppState.storageKey), original);
      final restoredGuest = await AppState.load();
      expect(restoredGuest.isGuest, isTrue);
      expect(restoredGuest.profileName, isNull);
      expect(restoredGuest.library.single.id, guestStory.id);
      expect(restoredGuest.bookmarkedSiteIds, {'kharkhorin'});
      expect(restoredGuest.textScale, 1.3);
    },
  );

  test(
    'accounts restore only their own stories, drafts, bookmarks and settings',
    () async {
      final a = await _account('account-a', name: 'Sarnai');
      await a.selectSite('tovkhon');
      await a.updateDraft(voiceId: 'moira', coverPath: '/local/a-cover.jpg');
      await a.queueDraft();
      final storyA = await a.createChronicle();
      await a.toggleStoryBookmark(storyA.id);
      await a.saveProgress(storyA.id, .75, 4200);
      await a.toggleSiteBookmark('tovkhon');
      await a.setPackInstalled('tovkhon', true);
      await a.setDarkMode(true);
      await a.setOffline(true);
      await a.setTextScale(1.25);
      await a.setPlaybackSpeed(1.5);

      final b = await _account('account-b', name: 'Bilguun');
      expect(b.library, isEmpty);
      expect(b.queuedDrafts, isEmpty);
      expect(b.bookmarkedSiteIds, isEmpty);
      expect(b.installedPacks, isEmpty);
      expect(b.draft.coverPath, isNull);
      expect(b.darkMode, isFalse);
      expect(b.offline, isFalse);
      expect(b.textScale, 1);
      expect(b.playbackSpeed, 1);
      await b.selectSite('erdene-zuu');
      final storyB = await b.createChronicle();
      await b.toggleSiteBookmark('erdene-zuu');

      final restoredA = await _account('account-a', name: 'Sarnai updated');
      expect(restoredA.profileName, 'Sarnai updated');
      expect(restoredA.isGuest, isFalse);
      expect(restoredA.library.single.id, storyA.id);
      expect(restoredA.library.single.bookmarked, isTrue);
      expect(restoredA.library.single.readingProgress, .75);
      expect(restoredA.library.single.audioPositionMs, 4200);
      expect(restoredA.storyById(storyB.id), isNull);
      expect(restoredA.queuedDrafts.single.siteId, 'tovkhon');
      expect(restoredA.draft.coverPath, '/local/a-cover.jpg');
      expect(restoredA.draft.voiceId, 'moira');
      expect(restoredA.bookmarkedSiteIds, {'tovkhon'});
      expect(restoredA.installedPacks, {'tovkhon'});
      expect(restoredA.darkMode, isTrue);
      expect(restoredA.offline, isTrue);
      expect(restoredA.textScale, 1.25);
      expect(restoredA.playbackSpeed, 1.5);

      final restoredB = await _account('account-b', name: 'Bilguun');
      expect(restoredB.library.single.id, storyB.id);
      expect(restoredB.bookmarkedSiteIds, {'erdene-zuu'});
      expect(restoredB.queuedDrafts, isEmpty);
      expect(restoredB.draft.siteId, 'erdene-zuu');
    },
  );

  test(
    'live, emulator and UIDs containing delimiters remain separate',
    () async {
      final identities = [
        ('same-uid', 'live'),
        ('same-uid', 'emulator'),
        ('a/b', 'emulator'),
        ('a_b', 'emulator'),
        ('a.b', 'emulator'),
        ('a=b', 'emulator'),
        ('Монгол', 'emulator'),
      ];
      for (var index = 0; index < identities.length; index++) {
        final (uid, environment) = identities[index];
        final state = await _account(uid, environment: environment);
        expect(state.textScale, 1);
        await state.setTextScale(.9 + index * .05);
      }
      for (var index = 0; index < identities.length; index++) {
        final (uid, environment) = identities[index];
        final restored = await _account(uid, environment: environment);
        expect(restored.textScale, closeTo(.9 + index * .05, .00001));
      }
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), hasLength(identities.length));
      expect(preferences.containsKey(AppState.storageKey), isFalse);
    },
  );

  test(
    'authenticated identity overrides stored or legacy profile mutations',
    () async {
      final state = await _account('account-a', name: '  Sarnai  ');
      await state.createChronicle();
      final preferences = await SharedPreferences.getInstance();
      final accountKey = preferences.getKeys().single;
      final saved =
          jsonDecode(preferences.getString(accountKey)!)
              as Map<String, dynamic>;
      saved['profileName'] = 'Another user';
      saved['isGuest'] = true;
      await preferences.setString(accountKey, jsonEncode(saved));

      final restored = await _account('account-a', name: 'Sarnai from Google');
      expect(restored.profileName, 'Sarnai from Google');
      expect(restored.isGuest, isFalse);
      expect(restored.library, hasLength(1));
      await restored.setProfile('Local alias');
      await restored.enterGuest();
      await restored.signOut();
      expect(restored.profileName, 'Sarnai from Google');
      expect(restored.isGuest, isFalse);
      await restored.resetDemo();
      expect(restored.profileName, 'Sarnai from Google');
      expect(restored.isGuest, isFalse);
      expect(restored.library, isEmpty);
    },
  );

  test(
    'queued writes from an old account keep their original storage key',
    () async {
      final a = await _account('account-a');
      final story = await a.createChronicle();
      final pendingWrites = [
        a.saveProgress(story.id, .1, 1000),
        a.saveProgress(story.id, .5, 5000),
        a.saveProgress(story.id, .9, 9000),
      ];
      final b = await _account('account-b');
      await b.setTextScale(1.4);
      final storyB = await b.createChronicle();
      // The old instance can still finish a callback after the account switch.
      pendingWrites.add(a.toggleStoryBookmark(story.id));
      await Future.wait(pendingWrites);

      final restoredB = await _account('account-b');
      expect(restoredB.textScale, 1.4);
      expect(restoredB.library.single.id, storyB.id);
      expect(restoredB.library.single.readingProgress, 0);
      expect(restoredB.library.single.bookmarked, isFalse);
      final restoredA = await _account('account-a');
      expect(restoredA.library.single.id, story.id);
      expect(restoredA.library.single.readingProgress, .9);
      expect(restoredA.library.single.audioPositionMs, 9000);
      expect(restoredA.library.single.bookmarked, isTrue);
      expect(restoredA.textScale, 1);
    },
  );

  test('invalid account inputs fail before touching any preferences', () async {
    for (final uid in ['', '   ', 'a' * 129]) {
      await expectLater(_account(uid), throwsArgumentError);
    }
    for (final environment in ['', 'production', 'Live', ' emulator ']) {
      await expectLater(
        _account('account-a', environment: environment),
        throwsArgumentError,
      );
    }
    await expectLater(_account('account-a', name: '  '), throwsArgumentError);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
    final boundaryUid = 'a' * 128;
    final valid = await _account(boundaryUid);
    await valid.setDarkMode(true);
    expect((await _account(boundaryUid)).darkMode, isTrue);
  });

  test(
    'broken account data recovers within the same account namespace',
    () async {
      final state = await _account('account-a', name: 'Sarnai');
      await state.setTextScale(1.2);
      final preferences = await SharedPreferences.getInstance();
      final accountKey = preferences.getKeys().single;
      await preferences.setString(accountKey, '{broken');
      final recovered = await _account('account-a', name: 'Sarnai');
      expect(recovered.profileName, 'Sarnai');
      expect(recovered.isGuest, isFalse);
      expect(recovered.textScale, 1);
      await recovered.setTextScale(1.3);
      expect(preferences.getKeys(), {accountKey});
      expect((await _account('account-a')).textScale, 1.3);
      expect((await AppState.load()).textScale, 1);
    },
  );
}
