import 'dart:typed_data';

import 'core_backup.dart';
import 'garment_media_store.dart';

CoreBackup createCoreBackup(GarmentMediaStore media) =>
    throw UnsupportedError('Browser backup is only available on web.');
Future<Uint8List?> pickCoreBackup() async =>
    throw UnsupportedError('Browser backup is only available on web.');
void downloadCoreBackup(Uint8List bytes, String filename) =>
    throw UnsupportedError('Browser backup is only available on web.');
void reloadCoreApp() =>
    throw UnsupportedError('Browser backup is only available on web.');
