import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'app_state.dart';
import 'pack_storage.dart';

/// Installs bundled demo bytes into persistent device/browser storage.
class DownloadController extends ChangeNotifier {
  DownloadController(
    this.state, {
    PackStorage? storage,
    Future<ByteData> Function(String)? loadAsset,
  }) : storage = storage ?? PackStorage(),
       loadAsset = loadAsset ?? rootBundle.load;
  final AppState state;
  final PackStorage storage;
  final Future<ByteData> Function(String) loadAsset;
  final Map<String, double> progress = {};
  final Map<String, int> byteCounts = {};
  final Map<String, String> errors = {};
  final Map<String, int> _tokens = {};
  final Map<String, Future<void>> _operations = {};
  final Set<String> busy = {};
  bool _disposed = false;

  bool _valid(String id, int token) => !_disposed && _tokens[id] == token;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> install(String siteId) {
    if (_disposed || state.installedPacks.contains(siteId)) {
      return Future.value();
    }
    if (busy.contains(siteId)) return _operations[siteId] ?? Future.value();
    final operation = _install(siteId);
    _operations[siteId] = operation;
    return operation;
  }

  Future<void> _install(String siteId) async {
    final token = (_tokens[siteId] ?? 0) + 1;
    _tokens[siteId] = token;
    busy.add(siteId);
    errors.remove(siteId);
    progress[siteId] = 0;
    _notify();
    final writtenKeys = <String>[];
    var committed = false;
    try {
      final site = state.siteById(siteId);
      final template = state.defaultTemplateForSite(siteId);
      final paths = [site.image, 'assets/audio/samantha/${template.id}.m4a'];
      final files = <String, Uint8List>{};
      for (final path in paths) {
        final data = await loadAsset(path);
        if (!_valid(siteId, token)) return;
        files[path] = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      }
      files['content.json'] = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'siteId': siteId,
            'title': template.title,
            'text': template.plainText,
            'kind': 'prepared-demo',
          }),
        ),
      );
      final total = files.values.fold<int>(
        0,
        (sum, bytes) => sum + bytes.length,
      );
      var written = 0;
      for (final entry in files.entries) {
        if (!_valid(siteId, token)) return;
        final key = '$siteId/${entry.key}';
        writtenKeys.add(key);
        await storage.put(key, entry.value);
        if (!_valid(siteId, token)) return;
        written += entry.value.length;
        progress[siteId] = written / total;
        _notify();
      }
      await storage.put(
        '$siteId/manifest',
        Uint8List.fromList(
          utf8.encode(jsonEncode({'keys': writtenKeys, 'bytes': total})),
        ),
      );
      if (!_valid(siteId, token)) return;
      await state.setPackInstalled(siteId, true);
      if (!_valid(siteId, token)) {
        await state.setPackInstalled(siteId, false);
        return;
      }
      byteCounts[siteId] = total;
      committed = true;
    } catch (_) {
      if (!_disposed) {
        errors[siteId] =
            'Storage is unavailable or full. Free some space and try again.';
      }
    } finally {
      if (!committed) {
        for (final key in [...writtenKeys, '$siteId/manifest']) {
          try {
            await storage.remove(key);
          } catch (_) {
            /* Reported as a retryable storage error. */
          }
        }
        if (!_disposed && state.installedPacks.contains(siteId)) {
          try {
            await state.setPackInstalled(siteId, false);
          } catch (_) {
            errors[siteId] =
                'Storage could not finish. Try removing the pack again.';
          }
        }
        progress.remove(siteId);
      }
      busy.remove(siteId);
      _operations.remove(siteId);
      _notify();
    }
  }

  void cancel(String siteId) {
    _tokens[siteId] = (_tokens[siteId] ?? 0) + 1;
    _notify();
  }

  Future<void> inspect() async {
    for (final id in state.installedPacks.toList()) {
      if (_disposed) return;
      try {
        final data = await storage.get('$id/manifest');
        if (_disposed) return;
        if (data == null) {
          await state.setPackInstalled(id, false);
        } else {
          final manifest =
              jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
          byteCounts[id] = manifest['bytes'] as int;
        }
      } catch (_) {
        if (!_disposed) errors[id] = 'The installed pack could not be checked.';
      }
    }
    _notify();
  }

  Future<void> remove(String siteId) async {
    cancel(siteId);
    // Wait for the in-flight writer to clean up, then remove any committed data.
    await _operations[siteId];
    if (_disposed) return;
    final bytes = await storage.get('$siteId/manifest');
    if (bytes != null) {
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      for (final key in (data['keys'] as List).cast<String>()) {
        await storage.remove(key);
      }
    }
    await storage.remove('$siteId/manifest');
    if (_disposed) return;
    byteCounts.remove(siteId);
    progress.remove(siteId);
    errors.remove(siteId);
    await state.setPackInstalled(siteId, false);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final id in _tokens.keys.toList()) {
      _tokens[id] = _tokens[id]! + 1;
    }
    super.dispose();
  }
}

class DownloadScope extends InheritedNotifier<DownloadController> {
  const DownloadScope({
    super.key,
    required DownloadController controller,
    required super.child,
  }) : super(notifier: controller);
  static DownloadController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DownloadScope>()!.notifier!;
}
