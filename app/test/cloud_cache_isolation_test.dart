import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cloud guest preferences do not import or overwrite the old emulator demo',
    () async {
      final local = await AppState.load();
      await local.toggleSiteBookmark('kharkhorin');
      final cloud = await AppState.load(projectId: 'ov-ai-5ae61');
      expect(cloud.bookmarkedSiteIds.contains('kharkhorin'), isFalse);
      await cloud.toggleSiteBookmark('erdene-zuu');
      final restoredLocal = await AppState.load();
      expect(restoredLocal.bookmarkedSiteIds.contains('kharkhorin'), isTrue);
      expect(restoredLocal.bookmarkedSiteIds.contains('erdene-zuu'), isFalse);
      final restoredCloud = await AppState.load(projectId: 'ov-ai-5ae61');
      expect(restoredCloud.bookmarkedSiteIds.contains('erdene-zuu'), isTrue);
    },
  );

  test(
    'identical UIDs in separate projects retain separate account caches',
    () async {
      Future<AppState> load(String? project) => AppState.loadForAccount(
        uid: 'same-uid',
        displayName: 'Traveler',
        environment: 'live',
        projectId: project,
      );
      final legacy = await load(null);
      await legacy.toggleSiteBookmark('kharkhorin');
      final cloud = await load('ov-ai-5ae61');
      expect(cloud.bookmarkedSiteIds.contains('kharkhorin'), isFalse);
      await cloud.toggleSiteBookmark('erdene-zuu');
      final otherProject = await load('another-project');
      expect(otherProject.bookmarkedSiteIds.contains('erdene-zuu'), isFalse);
      expect(
        (await load(null)).bookmarkedSiteIds.contains('kharkhorin'),
        isTrue,
      );
      expect(
        (await load('ov-ai-5ae61')).bookmarkedSiteIds.contains('erdene-zuu'),
        isTrue,
      );
    },
  );

  test(
    'cloud project caches cannot be attached to local emulator accounts',
    () async {
      await expectLater(
        AppState.loadForAccount(
          uid: 'uid',
          displayName: 'Traveler',
          environment: 'emulator',
          projectId: 'ov-ai-5ae61',
        ),
        throwsArgumentError,
      );
      expect(() => AppState.load(projectId: '../wrong'), throwsArgumentError);
    },
  );
}
