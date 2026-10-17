import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ov_chronicles/core/app_state.dart';
import 'package:ov_chronicles/core/download_controller.dart';
import 'package:ov_chronicles/core/pack_storage.dart';

class MemoryPackStorage extends PackStorage {
  final files = <String, Uint8List>{};
  Completer<void>? manifestGate;
  final manifestStarted = Completer<void>();
  bool failManifest = false;

  @override
  Future<void> put(String key, Uint8List bytes) async {
    if (key.endsWith('/manifest')) {
      if (!manifestStarted.isCompleted) manifestStarted.complete();
      await manifestGate?.future;
      if (failManifest) throw StateError('Storage full');
    }
    files[key] = bytes;
  }

  @override
  Future<Uint8List?> get(String key) async => files[key];
  @override
  Future<void> remove(String key) async {
    files.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ByteData> asset(String _) async =>
      ByteData.sublistView(Uint8List.fromList(List.generate(120, (i) => i)));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'installed files, bytes and state survive inspection and are removed together',
    () async {
      final state = await AppState.load();
      final storage = MemoryPackStorage();
      final downloads = DownloadController(
        state,
        storage: storage,
        loadAsset: asset,
      );
      await downloads.install('kharkhorin');
      expect(state.installedPacks, contains('kharkhorin'));
      expect(storage.files, hasLength(4));
      expect(downloads.byteCounts['kharkhorin'], greaterThan(240));
      final reopened = DownloadController(
        await AppState.load(),
        storage: storage,
        loadAsset: asset,
      );
      await reopened.inspect();
      expect(
        reopened.byteCounts['kharkhorin'],
        downloads.byteCounts['kharkhorin'],
      );
      await downloads.remove('kharkhorin');
      expect(storage.files, isEmpty);
      expect(state.installedPacks, isEmpty);
      downloads.dispose();
      reopened.dispose();
    },
  );

  test(
    'cancel during manifest commit cannot publish a completed pack',
    () async {
      final state = await AppState.load();
      final storage = MemoryPackStorage()..manifestGate = Completer<void>();
      final downloads = DownloadController(
        state,
        storage: storage,
        loadAsset: asset,
      );
      final install = downloads.install('kharkhorin');
      await storage.manifestStarted.future;
      final removal = downloads.remove('kharkhorin');
      storage.manifestGate!.complete();
      await Future.wait([install, removal]);
      expect(state.installedPacks, isEmpty);
      expect(storage.files, isEmpty);
      expect(downloads.busy, isEmpty);
      downloads.dispose();
    },
  );

  test('failed storage commit rolls back bytes and allows retry', () async {
    final state = await AppState.load();
    final storage = MemoryPackStorage()..failManifest = true;
    final downloads = DownloadController(
      state,
      storage: storage,
      loadAsset: asset,
    );
    await downloads.install('kharkhorin');
    expect(state.installedPacks, isEmpty);
    expect(storage.files, isEmpty);
    expect(downloads.errors['kharkhorin'], isNotNull);
    storage.failManifest = false;
    await downloads.install('kharkhorin');
    expect(state.installedPacks, contains('kharkhorin'));
    downloads.dispose();
  });

  test(
    'disposing while an install is committing cleans up without notification',
    () async {
      final state = await AppState.load();
      final storage = MemoryPackStorage()..manifestGate = Completer<void>();
      final downloads = DownloadController(
        state,
        storage: storage,
        loadAsset: asset,
      );
      final install = downloads.install('kharkhorin');
      await storage.manifestStarted.future;
      downloads.dispose();
      storage.manifestGate!.complete();
      await install;
      expect(storage.files, isEmpty);
      expect(state.installedPacks, isEmpty);
    },
  );
}
