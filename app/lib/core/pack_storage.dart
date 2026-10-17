export 'pack_storage_stub.dart'
    if (dart.library.io) 'pack_storage_io.dart'
    if (dart.library.html) 'pack_storage_web.dart';
