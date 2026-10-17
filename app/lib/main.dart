import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth/auth_scope.dart';
import 'auth/social_auth.dart';
import 'core/app_scope.dart';
import 'core/app_state.dart';
import 'core/audio_controller.dart';
import 'core/download_controller.dart';
import 'core/navigation_motion.dart';
import 'core/theme.dart';
import 'screens/discovery_screens.dart';
import 'screens/entry_screens.dart';
import 'screens/inscribe_screens.dart';
import 'screens/library_screens.dart';
import 'screens/reader_screens.dart';
import 'screens/share_screen.dart';
import 'screens/travel_screens.dart';
import 'screens/utility_screens.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment('AUTH_MODE', defaultValue: 'live');
  if (mode != 'live' && mode != 'emulator') {
    throw StateError('AUTH_MODE must be live or emulator.');
  }
  final auth = SocialAuthController(
    mode == 'emulator'
        ? FirebaseAuthGateway.emulator(
            emulatorHost: const String.fromEnvironment(
              'FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1',
            ),
          )
        : FirebaseAuthGateway.live(),
  );
  await auth.initialize();
  runApp(OvSessionApp(auth: auth));
}

/// Replaces the full reader/player/navigation tree when the account changes.
/// Local caches are selected by verified Firebase UID, never an entered name.
class OvSessionApp extends StatefulWidget {
  const OvSessionApp({super.key, required this.auth});
  final SocialAuthController auth;

  @override
  State<OvSessionApp> createState() => _OvSessionAppState();
}

class _OvSessionAppState extends State<OvSessionApp> {
  late String _sessionKey;
  late Future<AppState> _state;
  bool _signedOut = false;

  String get _currentKey => widget.auth.isSignedIn
      ? jsonEncode([
          widget.auth.isEmulator,
          widget.auth.identity!.uid,
          widget.auth.identity!.displayName,
        ])
      : 'guest';

  Future<AppState> _loadState() {
    final identity = widget.auth.identity;
    if (widget.auth.isSignedIn && identity != null) {
      return AppState.loadForAccount(
        uid: identity.uid,
        displayName: identity.displayName,
        environment: widget.auth.isEmulator ? 'emulator' : 'live',
      );
    }
    return AppState.load();
  }

  @override
  void initState() {
    super.initState();
    _sessionKey = _currentKey;
    _state = _loadState();
    widget.auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final nextKey = _currentKey;
    if (!mounted || nextKey == _sessionKey) return;
    setState(() {
      _signedOut = nextKey == 'guest';
      _sessionKey = nextKey;
      _state = _loadState();
    });
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    widget.auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScope(
    controller: widget.auth,
    child: FutureBuilder<AppState>(
      future: _state,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            theme: buildOvTheme(false),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            theme: buildOvTheme(false),
            home: Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => setState(() => _state = _loadState()),
                  child: const Text('Retry loading your local library'),
                ),
              ),
            ),
          );
        }
        final state = snapshot.requireData;
        return OvApp(
          key: ValueKey(_sessionKey),
          state: state,
          initialLocation: widget.auth.isSignedIn
              ? '/steppe'
              : !_signedOut && state.isGuest
              ? '/steppe'
              : '/welcome',
        );
      },
    ),
  );
}

class OvApp extends StatefulWidget {
  const OvApp({super.key, required this.state, this.initialLocation});
  final AppState state;
  final String? initialLocation;
  @override
  State<OvApp> createState() => _OvAppState();
}

class _OvAppState extends State<OvApp> with WidgetsBindingObserver {
  late final AudioController _audio = AudioController(widget.state);
  late final DownloadController _downloads = DownloadController(widget.state);
  late final GoRouter _router = GoRouter(
    initialLocation:
        widget.initialLocation ??
        (widget.state.profileName != null || widget.state.isGuest
            ? '/steppe'
            : '/welcome'),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/welcome'),
      ovRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      ovRoute(
        path: '/profile-setup',
        builder: (_, _) => const DemoProfileScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) {
          final path = state.uri.path;
          final activeTab = switch (path) {
            '/inscribe/place' => 'inscribe',
            '/orda' => 'orda',
            _ when path == '/scrolls' || path.startsWith('/journey') =>
              'scrolls',
            _ => 'steppe',
          };
          return AppNavigationShell(activeTab: activeTab, child: child);
        },
        routes: [
          ovRoute(path: '/steppe', builder: (_, _) => const SteppeScreen()),
          ovRoute(
            path: '/inscribe/place',
            builder: (_, _) => const PlaceScreen(),
          ),
          ovRoute(path: '/scrolls', builder: (_, _) => const LibraryScreen()),
          ovRoute(path: '/orda', builder: (_, _) => const ProfileScreen()),
          ovRoute(path: '/field', builder: (_, _) => const FieldMapScreen()),
          ovRoute(path: '/journey', builder: (_, _) => const JourneyScreen()),
          ovRoute(
            path: '/journey/:id',
            builder: (_, state) =>
                JourneyScreen(id: state.pathParameters['id']),
          ),
        ],
      ),
      ovRoute(path: '/inscribe/tone', builder: (_, _) => const ToneScreen()),
      ovRoute(path: '/inscribe/voice', builder: (_, _) => const VoiceScreen()),
      ovRoute(path: '/writing', builder: (_, _) => const WritingScreen()),
      ovRoute(
        path: '/reader/:id',
        builder: (_, state) => ReaderScreen(id: state.pathParameters['id']!),
      ),
      ovRoute(
        path: '/reader/:id/end',
        builder: (_, state) => ReaderEndScreen(id: state.pathParameters['id']!),
      ),
      ovRoute(
        path: '/geofence',
        builder: (_, state) =>
            GeofenceScreen(live: state.uri.queryParameters['mode'] == 'live'),
      ),
      ovRoute(path: '/offline', builder: (_, _) => const OfflineScreen()),
      ovRoute(
        path: '/share/:id',
        builder: (_, state) => ShareScreen(id: state.pathParameters['id']!),
      ),
      ovRoute(
        path: '/playback',
        builder: (_, state) =>
            PlaybackScreen(id: state.uri.queryParameters['story']),
      ),
      ovRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ovRoute(path: '/downloads', builder: (_, _) => const DownloadsScreen()),
      ovRoute(
        path: '/demo/:templateId',
        builder: (_, state) =>
            OpenPreparedStory(templateId: state.pathParameters['templateId']!),
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('That path is not in this demo.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/steppe'),
                child: const Text('Return to the steppe'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_downloads.inspect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _audio.player.playing) {
      unawaited(_audio.toggle());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _audio.dispose();
    _downloads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: widget.state,
    child: AudioScope(
      controller: _audio,
      child: DownloadScope(
        controller: _downloads,
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (_, _) => MaterialApp.router(
            title: 'Öv · Stories of the steppe',
            debugShowCheckedModeBanner: false,
            theme: buildOvTheme(false),
            darkTheme: buildOvTheme(true),
            themeMode: widget.state.darkMode ? ThemeMode.dark : ThemeMode.light,
            routerConfig: _router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(widget.state.textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
}

class OpenPreparedStory extends StatefulWidget {
  const OpenPreparedStory({super.key, required this.templateId});
  final String templateId;
  @override
  State<OpenPreparedStory> createState() => _OpenPreparedStoryState();
}

class _OpenPreparedStoryState extends State<OpenPreparedStory> {
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = AppScope.of(context);
      if (!app.templates.any((template) => template.id == widget.templateId)) {
        setState(
          () => _error = 'This prepared story is not in the demo collection.',
        );
        return;
      }
      try {
        final story = await app.createChronicle(templateId: widget.templateId);
        if (mounted) context.go('/reader/${story.id}');
      } catch (_) {
        if (mounted) setState(() => _error = 'The story could not be opened.');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _error == null
          ? const CircularProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/steppe'),
                    child: const Text('Explore places'),
                  ),
                ],
              ),
            ),
    ),
  );
}
