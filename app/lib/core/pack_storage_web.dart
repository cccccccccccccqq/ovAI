// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class PackStorage {
  Future<dynamic> _database() async {
    final factory = html.window.indexedDB;
    if (factory == null) {
      throw UnsupportedError('Browser storage is unavailable.');
    }
    return factory.open(
      'ov_demo_packs',
      version: 1,
      onUpgradeNeeded: (event) {
        final dynamic database = (event.target as dynamic).result;
        database.createObjectStore('files');
      },
    );
  }

  Future<void> put(String key, Uint8List bytes) async {
    final db = await _database();
    try {
      final transaction = db.transaction('files', 'readwrite');
      await transaction.objectStore('files').put(bytes, key);
      await transaction.completed;
    } finally {
      db.close();
    }
  }

  Future<Uint8List?> get(String key) async {
    final db = await _database();
    try {
      final transaction = db.transaction('files', 'readonly');
      final value = await transaction.objectStore('files').getObject(key);
      await transaction.completed;
      return value == null
          ? null
          : Uint8List.fromList((value as List).cast<int>());
    } finally {
      db.close();
    }
  }

  Future<void> remove(String key) async {
    final db = await _database();
    try {
      final transaction = db.transaction('files', 'readwrite');
      await transaction.objectStore('files').delete(key);
      await transaction.completed;
    } finally {
      db.close();
    }
  }
}
