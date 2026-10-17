// Developer entry: flutter run -t lib/main_firebase_check.dart
// Start and seed the local Firebase emulators first. For Android's emulator,
// add --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'backend/firebase_backend.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FirebaseCheckApp());
}

class FirebaseCheckApp extends StatelessWidget {
  const FirebaseCheckApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Firebase local backend check',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const _CheckPage(),
  );
}

class _CheckPage extends StatefulWidget {
  const _CheckPage();

  @override
  State<_CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<_CheckPage> {
  static const _host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const _limit = Duration(seconds: 30);
  Future<FirebaseBackend>? _connection;
  final _logs = <String>[];
  bool _running = false;
  int _runs = 0;

  void _log(String message) {
    if (mounted) setState(() => _logs.add(message));
  }

  void _expect(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  Future<T> _waitFor<T>(Stream<T> stream, bool Function(T) accept) =>
      stream.timeout(_limit).firstWhere(accept);

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _logs.clear();
    });
    FirebaseBackend? backend;
    String? createdId;
    var deleted = false;
    var passed = false;
    try {
      _log('Connecting to local emulators at $_host…');
      _connection ??= FirebaseBackend.initializeEmulators(host: _host);
      final connected = await _connection!.timeout(_limit);
      backend = connected;
      await connected.signOut().timeout(_limit);
      final credential = await connected.signInAnonymously().timeout(_limit);
      final uid = credential.user?.uid;
      _expect(uid != null, 'Anonymous sign-in did not return a user.');
      _log('Anonymous sign-in passed.');

      final sites = await _waitFor(
        connected.watchSites(),
        (items) => items.length == 4,
      );
      final templates = await _waitFor(
        connected.watchPublishedTemplates(),
        (items) => items.length == 11,
      );
      final source = templates.singleWhere((item) => item.id == 'silver-tree');
      _expect(source.voiceIds.contains('karen'), 'Karen audio is not seeded.');
      _log(
        'Typed catalog parsed: ${sites.length} sites, ${templates.length} published templates.',
      );

      final profile = await connected
          .ensureProfile(EnsureProfileRequest(displayName: 'Backend check'))
          .timeout(_limit);
      _expect(profile.uid == uid, 'Profile owner mismatch.');
      final savedProfile = await _waitFor(
        connected.watchProfile(),
        (item) => item?.displayName == 'Backend check',
      );
      _expect(savedProfile?.uid == uid, 'Stored profile owner mismatch.');
      _log('Profile callable and typed profile stream passed.');

      final request = CreatePreparedChronicleRequest(
        requestId:
            'flutter-check-${DateTime.now().microsecondsSinceEpoch}-${++_runs}',
        templateId: 'silver-tree',
        voiceId: 'karen',
      );
      final created = await connected
          .createPreparedChronicle(request)
          .timeout(_limit);
      createdId = created.chronicleId;
      _expect(
        created.status == BackendChronicleStatus.ready,
        'New chronicle is not ready.',
      );
      final replay = await connected
          .createPreparedChronicle(request)
          .timeout(_limit);
      _expect(
        replay.replayed && replay.chronicleId == createdId,
        'Retry created a second chronicle.',
      );
      _log('Create and idempotent replay passed.');

      final chronicle = await _waitFor(
        connected.watchChronicle(createdId),
        (item) => item != null,
      );
      final saved = chronicle!;
      _expect(
        saved.uid == uid &&
            saved.templateId == source.id &&
            saved.voiceId == 'karen' &&
            saved.contentKind == 'prepared-demo' &&
            saved.contentVersion == source.contentVersion &&
            saved.content.segments.isNotEmpty &&
            saved.content.citations.isNotEmpty &&
            saved.content.plainText == source.content.plainText,
        'Saved content snapshot did not match the prepared source.',
      );
      _log(
        'Private snapshot parsed: ${saved.content.segments.length} segments, ${saved.content.citations.length} citations.',
      );
      final audioReference = connected.storageAudioReference(saved);
      _expect(
        audioReference != null,
        'Audio is unavailable; seed with --with-media.',
      );
      final bytes = await audioReference!
          .getData(5 * 1024 * 1024)
          .timeout(_limit);
      _expect(
        bytes != null &&
            bytes.length > 1000 &&
            String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp',
        'Downloaded audio is missing a valid M4A header.',
      );
      _log('Authenticated Storage fetch passed: ${bytes!.length} M4A bytes.');

      await connected
          .patchLibraryItem(
            PatchLibraryItemRequest(
              chronicleId: createdId,
              bookmarked: true,
              readingProgress: 0.5,
              audioPositionMs: 1000,
            ),
          )
          .timeout(_limit);
      await _waitFor(
        connected.watchLibrary(),
        (items) => items.any(
          (item) =>
              item.chronicleId == createdId &&
              item.uid == uid &&
              item.bookmarked &&
              item.readingProgress == 0.5 &&
              item.audioPositionMs == 1000,
        ),
      );
      _log('Bookmark, reading progress, and audio position round trip passed.');

      final removed = await connected
          .deleteChronicle(createdId)
          .timeout(_limit);
      _expect(
        removed.status == BackendChronicleStatus.deleted,
        'Delete did not return a tombstone.',
      );
      deleted = true;
      final deletedReplay = await connected
          .createPreparedChronicle(request)
          .timeout(_limit);
      _expect(
        deletedReplay.status == BackendChronicleStatus.deleted &&
            deletedReplay.replayed &&
            deletedReplay.chronicleId == createdId,
        'Retry resurrected the deleted chronicle.',
      );
      await _waitFor(
        connected.watchLibrary(),
        (items) => items.every((item) => item.chronicleId != createdId),
      );
      _log('Delete, deleted replay, and library removal passed.');
      passed = true;
    } catch (error) {
      final detail = error is FirebaseException
          ? '${error.plugin}/${error.code}: ${error.message ?? 'No details'}'
          : error.toString();
      _log('FAIL: $detail');
      _log('Check emulator processes, ports, and seed: npm run seed:emulator.');
    } finally {
      if (backend != null) {
        if (createdId != null && !deleted) {
          try {
            await backend.deleteChronicle(createdId).timeout(_limit);
            _log('Failure cleanup: created chronicle deleted.');
          } catch (_) {
            _log('Failure cleanup could not delete the local check chronicle.');
          }
        }
        try {
          await backend.signOut().timeout(_limit);
          _log('Signed out.');
        } catch (_) {
          passed = false;
          _log('FAIL: local sign-out did not complete.');
        }
      }
      if (passed) _log('PASS — FlutterFire local backend check completed.');
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Firebase local backend check')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Developer check · local emulators only'),
        const SizedBox(height: 8),
        const SelectableText(
          'Project: ${FirebaseBackend.emulatorProjectId}\nHost: $_host\nAuth 9099 · Firestore 18080 · Functions 5001 · Storage 9199',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _running ? null : _run,
          child: const Text('Run backend check'),
        ),
        if (_running)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 16),
        SelectableText(
          _logs.isEmpty
              ? 'Nothing connects or signs in until you press Run.'
              : _logs.join('\n\n'),
        ),
      ],
    ),
  );
}
