import 'dart:typed_data';

class PackStorage {
  Future<void> put(String key, Uint8List bytes) async =>
      throw UnsupportedError('Local packs are unavailable on this platform.');
  Future<Uint8List?> get(String key) async => null;
  Future<void> remove(String key) async {}
}
