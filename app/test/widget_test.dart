import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:ov_chronicles/main.dart';
import 'package:ov_chronicles/screens/discovery_screens.dart';
import 'package:ov_chronicles/screens/entry_screens.dart';
import 'package:ov_chronicles/screens/inscribe_screens.dart';
import 'package:ov_chronicles/screens/library_screens.dart';
import 'package:ov_chronicles/screens/reader_screens.dart';
import 'package:ov_chronicles/screens/share_screen.dart';
import 'package:ov_chronicles/screens/travel_screens.dart';
import 'package:ov_chronicles/screens/utility_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Native decoding is covered by device/browser verification. Widget tests
/// render the playback error state instead of invoking a platform audio decoder.
void _mockAudioChannels() {
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
        final id = (call.arguments as Map<dynamic, dynamic>)['id'] as String;
        messenger.setMockMethodCallHandler(
          MethodChannel('com.ryanheise.just_audio.methods.$id'),
          (call) async {
            if (call.method == 'load') {
              throw PlatformException(
                code: 'widget_test_audio',
                message: 'No native decoder in widget tests.',
              );
            }
            return <String, dynamic>{};
          },
        );
        for (final prefix in ['events', 'data']) {
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.$prefix.$id'),
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
    _mockAudioChannels();
  });

  testWidgets(
    'a traveller can create a profile and prepare the selected story',
    (tester) async {
      _phoneSize(tester);
      final state = await AppState.load();
      await tester.pumpWidget(OvApp(state: state));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);

      await _tapVisible(tester, find.text('Begin your journey'));
      expect(find.byType(DemoProfileScreen), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Saran');
      tester.testTextInput.hide();
      await _tapVisible(tester, find.text('Start exploring'));
      expect(find.byType(SteppeScreen), findsOneWidget);
      expect(state.profileName, 'Saran');
      expect(find.text('4 places to discover'), findsOneWidget);

      await _tapVisible(tester, find.text('Inscribe'));
      expect(find.byType(PlaceScreen), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erdene Zuu').last);
      await tester.pumpAndSettle();
      expect(state.draft.siteId, 'erdene-zuu');

      await _tapVisible(tester, find.text('Next: set the tone'));
      await _tapVisible(tester, find.text('Chronicle · tovchoo'));
      expect(state.draftTemplate.id, 'erdene-notebook');
      await _tapVisible(tester, find.text('Next: choose a voice'));
      expect(find.byType(VoiceScreen), findsOneWidget);
      await _tapVisible(tester, find.text('Daniel'));
      await tester.ensureVisible(
        find.text('Narrator  Daniel', findRichText: true),
      );
      await tester.pumpAndSettle();
      expect(state.draft.voiceId, 'daniel');
      expect(
        find.text('Genre  Chronicle · tovchoo', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Style  Plain modern', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Seed  ${state.draft.seed}', findRichText: true),
        findsOneWidget,
      );

      // Preparing local content should save the selected story and open Reader.
      await tester.ensureVisible(find.text('Prepare my chronicle'));
      await tester.tap(find.text('Prepare my chronicle'));
      await tester.pump();
      for (var step = 0; step < 4; step++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(state.library, hasLength(1));
      expect(state.library.single.templateId, 'erdene-notebook');
      expect(state.library.single.voiceId, 'daniel');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('a guest can leave the profile gate and return to exploration', (
    tester,
  ) async {
    _phoneSize(tester);
    final state = await AppState.load();
    await state.enterGuest();
    await tester.pumpWidget(OvApp(state: state));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(SteppeScreen)));
    router.go('/inscribe/voice');
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Prepare my chronicle'));
    expect(find.byType(DemoProfileScreen), findsOneWidget);
    await _tapVisible(tester, find.text('Continue as a guest'));
    expect(find.byType(SteppeScreen), findsOneWidget);
    expect(find.byType(VoiceScreen), findsNothing);
    expect(state.isGuest, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'all 19 prototype screens render at iPhone size without layout errors',
    (tester) async {
      _phoneSize(tester);
      final state = await AppState.load();
      await state.setProfile('Saran');
      final story = await state.createChronicle();
      await state.queueDraft();
      await tester.pumpWidget(OvApp(state: state));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(SteppeScreen)));

      final routes = <(String, Type)>[
        ('/welcome', WelcomeScreen),
        ('/profile-setup', DemoProfileScreen),
        ('/steppe', SteppeScreen),
        ('/inscribe/place', PlaceScreen),
        ('/inscribe/tone', ToneScreen),
        ('/inscribe/voice', VoiceScreen),
        ('/writing', WritingScreen),
        ('/reader/${story.id}', ReaderScreen),
        ('/reader/${story.id}/end', ReaderEndScreen),
        ('/scrolls', LibraryScreen),
        ('/profile', ProfileScreen),
        ('/field', FieldMapScreen),
        ('/geofence', GeofenceScreen),
        ('/offline', OfflineScreen),
        ('/journey/${story.id}', JourneyScreen),
        ('/share/${story.id}', ShareScreen),
        ('/playback?story=${story.id}', PlaybackScreen),
        ('/settings', SettingsScreen),
        ('/downloads', DownloadsScreen),
      ];
      for (final route in routes) {
        // The illustrated offline map needs no HTTP tiles. Native permission
        // prompts, image picking and sharing are only invoked by explicit taps.
        if (route.$1 == '/field') await state.setOffline(true);
        router.go(route.$1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(route.$2), findsOneWidget, reason: route.$1);
        expect(tester.takeException(), isNull, reason: route.$1);
      }
      // Finish outstanding async platform cleanup before ending the test.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
