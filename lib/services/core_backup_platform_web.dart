import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'core_backup.dart';
import 'garment_media_store.dart';
import 'web_core_backup_io.dart' as io;
import 'web_core_backup_records.dart';

CoreBackup createCoreBackup(GarmentMediaStore media) =>
    CoreBackup(records: WebCoreBackupRecords(), media: media);
Future<Uint8List?> pickCoreBackup() => io.pickCoreBackup();
void downloadCoreBackup(Uint8List bytes, String filename) =>
    io.downloadCoreBackup(bytes, filename);
void reloadCoreApp() => web.window.location.reload();
