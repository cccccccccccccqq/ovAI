import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ov_chronicles/auth/social_auth.dart';
import 'package:ov_chronicles/core/app_scope.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:ov_chronicles/main.dart';
import 'package:ov_chronicles/screens/discovery_screens.dart';
import 'package:ov_chronicles/screens/entry_screens.dart';
import 'package:ov_chronicles/screens/library_screens.dart';
import 'package:ov_chronicles/screens/sign_in_screen.dart';
import 'package:ov_chronicles/screens/utility_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppIdentity _person(String uid, String name) => AppIdentity(
  uid: uid,
  displayName: name,
  email: '$uid@example.test',
  providers: {'google.com'},
);

class _WidgetAuthGateway implements AuthGateway {
  _WidgetAuthGateway({this.isEmulator = true, AppIdentity? restored})
    : _identity = restored;

  @override
  final bool isEmulator;
  AppIdentity? _identity;
  final _changes = StreamController<AppIdentity?>.broadcast(sync: true);
  AppIdentity nextIdentity = _person('account-a', 'Saran');
  Future<AppIdentity> Function(SocialProvider)? onSignIn;
  Future<void> Function()? onSignOut;
  int signInCalls = 0;

  @override
  AppIdentity? get currentIdentity => _identity;
  @override
  Stream<AppIdentity?> get identityChanges => _changes.stream;
  @override
  Future<void> initialize() async {}

  void emitIdentity(AppIdentity? identity) {
    _identity = identity;
    _changes.add(identity);
  }

  @override
  Future<AppIdentity> signIn(SocialProvider provider) async {
    signInCalls++;
    _identity = await (onSignIn?.call(provider) ?? Future.value(nextIdentity));
    _changes.add(_identity);
    return _identity!;
  }

  @override
  Future<void> signOut() async {
    await onSignOut?.call();
    _identity = null;
    _changes.add(null);
  }

  @override
  Future<void> dispose() => _changes.close();
}

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
              throw PlatformException(code: 'widget_test_audio');
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

Future<SocialAuthController> _mount(
  WidgetTester tester,
  _WidgetAuthGateway gateway, {
  String? cloudProjectId,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = SocialAuthController(gateway);
  await auth.initialize();
  await tester.pumpWidget(
    OvSessionApp(auth: auth, cloudProjectId: cloudProjectId),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  return auth;
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _provider(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(OutlinedButton));

AppState _state(WidgetTester tester) =>
    AppScope.of(tester.element(find.byType(SteppeScreen)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockAudioChannels();
  });

  testWidgets('welcome opens Google and Apple sign-in without a name form', (
    tester,
  ) async {
    await _mount(tester, _WidgetAuthGateway());
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await _tap(tester, 'Begin your journey');
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('LOCAL TEST · SIMULATED ACCOUNTS'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(_provider('Continue with Google'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<OutlinedButton>(_provider('Continue with Apple')).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cloud account copy distinguishes saved stories from device settings',
    (tester) async {
      final gateway = _WidgetAuthGateway(isEmulator: false);
      await _mount(tester, gateway, cloudProjectId: 'ov-ai-5ae61');
      expect(
        find.text(
          'Prepared stories. Real places.\nSign in to save your journey.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Begin your journey');
      expect(
        find.text(
          'Your stories and reading progress are saved to your account. Reading settings and downloads stay on this device.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Stories and reading progress are currently saved on this device',
        ),
        findsNothing,
      );
      await _tap(tester, 'Continue with Google');
      await _tap(tester, 'Profile');
      expect(find.text('CONNECTED ACCOUNT'), findsOneWidget);
      expect(
        find.text(
          'öv AI · v0.1\nStories and reading progress are saved to your account. Reading settings and downloads stay on this device.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Settings');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('READING SETTINGS · ON THIS DEVICE'), findsOneWidget);
      expect(find.text('Stories saved to your account'), findsOneWidget);
      expect(find.textContaining('account sync are planned'), findsNothing);
      await _tap(tester, 'Reset device settings');
      expect(find.text('Reset this device?'), findsOneWidget);
      expect(
        find.textContaining(
          'Stories and progress saved to your account will remain.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Keep my settings');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('live Apple sign-in stays disabled before provider setup', (
    tester,
  ) async {
    await _mount(tester, _WidgetAuthGateway(isEmulator: false));
    await _tap(tester, 'Begin your journey');
    expect(
      tester.widget<OutlinedButton>(_provider('Continue with Apple')).onPressed,
      isNull,
    );
    expect(find.text('Apple sign-in is coming soon.'), findsOneWidget);
    expect(find.text('LOCAL TEST · SIMULATED ACCOUNTS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'provider loading, cancellation, failure, and retry reach real profile',
    (tester) async {
      final pending = Completer<AppIdentity>();
      final gateway = _WidgetAuthGateway()..onSignIn = (_) => pending.future;
      final auth = await _mount(tester, gateway);
      await _tap(tester, 'Begin your journey');
      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      for (final label in ['Continue with Google', 'Continue with Apple']) {
        expect(
          tester.widget<OutlinedButton>(_provider(label)).onPressed,
          isNull,
        );
      }
      expect(gateway.signInCalls, 1);
      pending.completeError(const AuthFailure('popup-closed-by-user'));
      await tester.pumpAndSettle();
      expect(auth.identity, isNull);
      expect(auth.errorMessage, isNull);
      expect(find.byType(SignInScreen), findsOneWidget);

      gateway.onSignIn = (_) async {
        throw const AuthFailure('network-request-failed');
      };
      await _tap(tester, 'Continue with Google');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      gateway.onSignIn = null;
      await _tap(tester, 'Continue with Google');
      expect(find.byType(SteppeScreen), findsOneWidget);
      expect(_state(tester).profileName, 'Saran');
      expect(auth.identity?.uid, 'account-a');
      await _tap(tester, 'Profile');
      expect(find.text('Saran'), findsWidgets);
      expect(find.text('account-a@example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sign-out and account switching isolate each saved library', (
    tester,
  ) async {
    final gateway = _WidgetAuthGateway();
    await _mount(tester, gateway);
    await _tap(tester, 'Begin your journey');
    await _tap(tester, 'Continue with Google');
    final stateA = _state(tester);
    final storyA = await stateA.createChronicle(templateId: 'silver-tree');
    await _tap(tester, 'Profile');
    await _tap(tester, 'Sign out');
    expect(find.byType(WelcomeScreen), findsOneWidget);

    gateway.nextIdentity = _person('account-b', 'Naran');
    await _tap(tester, 'Begin your journey');
    await _tap(tester, 'Continue with Google');
    final stateB = _state(tester);
    expect(stateB.profileName, 'Naran');
    expect(stateB.library, isEmpty);
    await stateB.createChronicle(templateId: 'workshop');
    await _tap(tester, 'Profile');
    await _tap(tester, 'Sign out');

    gateway.nextIdentity = _person('account-a', 'Saran');
    await _tap(tester, 'Begin your journey');
    await _tap(tester, 'Continue with Google');
    final restoredA = _state(tester);
    expect(restoredA.library, hasLength(1));
    expect(restoredA.library.single.id, storyA.id);
    expect(restoredA.library.single.templateId, 'silver-tree');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restored account opens Steppe and failed sign-out keeps its profile',
    (tester) async {
      final gateway =
          _WidgetAuthGateway(restored: _person('account-a', 'Saran'))
            ..onSignOut = () async {
              throw const AuthFailure('network-request-failed');
            };
      final auth = await _mount(tester, gateway);
      expect(find.byType(SteppeScreen), findsOneWidget);
      await _tap(tester, 'Profile');
      await _tap(tester, 'Sign out');
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Saran'), findsWidgets);
      expect(auth.identity?.uid, 'account-a');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account keys cannot collide when UID and name contain colons', (
    tester,
  ) async {
    final gateway = _WidgetAuthGateway(restored: _person('a:b', 'c'));
    await _mount(tester, gateway);
    final first = _state(tester);
    await first.createChronicle(templateId: 'silver-tree');
    gateway.emitIdentity(_person('a', 'b:c'));
    await tester.pumpAndSettle();
    final second = _state(tester);
    expect(identical(first, second), isFalse);
    expect(second.profileName, 'b:c');
    expect(second.library, isEmpty);
    expect(first.library, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account screen displays failed sign-out without dropping identity',
    (tester) async {
      final gateway =
          _WidgetAuthGateway(restored: _person('account-a', 'Saran'))
            ..onSignOut = () async {
              throw const AuthFailure('network-request-failed');
            };
      final auth = await _mount(tester, gateway);
      GoRouter.of(
        tester.element(find.byType(SteppeScreen)),
      ).go('/profile-setup');
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      await _tap(tester, 'Sign out');
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(auth.isSignedIn, isTrue);
      expect(auth.identity?.uid, 'account-a');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.text('Continue exploring'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
