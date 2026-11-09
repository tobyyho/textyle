import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'core_backup.dart';

Future<Uint8List?> pickCoreBackup() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json';
  final done = Completer<Uint8List?>();
  Future<void> readSelectedFile() async {
    try {
      final file = input.files?.item(0);
      if (file == null) {
        done.complete(null);
        return;
      }
      if (file.size > CoreBackup.maxArchiveBytes) {
        throw const BackupException('Backup file exceeds 128 MiB.');
      }
      final buffer = await file.arrayBuffer().toDart;
      done.complete(buffer.toDart.asUint8List());
    } on Object catch (error) {
      done.completeError(error);
    }
  }

  input.onchange = ((web.Event _) {
    readSelectedFile();
  }).toJS;
  input.oncancel = ((web.Event _) {
    if (!done.isCompleted) done.complete(null);
  }).toJS;
  input.click();
  return done.future;
}

void downloadCoreBackup(Uint8List bytes, String filename) {
  final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  Future<void>.delayed(
      const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}
