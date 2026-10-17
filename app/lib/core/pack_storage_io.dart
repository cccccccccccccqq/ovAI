import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class PackStorage {
  Future<File> _file(String key) async {
    final root = await getApplicationDocumentsDirectory();
    final path = key.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final folder = Directory('${root.path}/ov_demo_packs');
    await folder.create(recursive: true);
    return File('${folder.path}/$path');
  }

  Future<void> put(String key, Uint8List bytes) async =>
      (await _file(key)).writeAsBytes(bytes, flush: true);
  Future<Uint8List?> get(String key) async {
    final file = await _file(key);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> remove(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }
}
