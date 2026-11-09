import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'core_backup.dart';

/// Reads the existing three CORE keys and commits replacements together in
/// one IndexedDB transaction. Media is staged first by CoreBackup.
class WebCoreBackupRecords implements CoreBackupRecords {
  Future<web.IDBDatabase> _open() {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open('textyle.wardrobe-records.v1', 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains('records'))
        db.createObjectStore('records');
    }).toJS;
    request.onsuccess = ((web.Event _) =>
        done.complete(request.result as web.IDBDatabase)).toJS;
    request.onerror = ((web.Event _) => done.completeError(
        const BackupException('Wardrobe storage could not be opened.'))).toJS;
    return done.future;
  }

  @override
  Future<Map<String, String?>> readAll() async {
    final db = await _open();
    try {
      final values = <String, String?>{};
      final done = Completer<Map<String, String?>>();
      final tx = db.transaction('records'.toJS, 'readonly');
      final store = tx.objectStore('records');
      tx.oncomplete = ((web.Event _) {
        // Match WebInventoryPersistence's read-only legacy fallback.
        values[CoreBackup.inventoryKey] ??=
            web.window.localStorage.getItem(CoreBackup.inventoryKey);
        done.complete(values);
      }).toJS;
      void fail(web.Event _) {
        if (!done.isCompleted) {
          done.completeError(
              const BackupException('Wardrobe data could not be read.'));
        }
      }

      tx.onerror = fail.toJS;
      tx.onabort = fail.toJS;
      for (final key in CoreBackup.keys) {
        final request = store.get(key.toJS);
        request.onsuccess = ((web.Event _) {
          final result = request.result;
          values[key] = result == null ? null : (result as JSString).toDart;
        }).toJS;
        request.onerror = fail.toJS;
      }
      return await done.future;
    } finally {
      db.close();
    }
  }

  @override
  Future<void> replaceAll(Map<String, String> values) async {
    if (values.length != CoreBackup.keys.length ||
        !CoreBackup.keys.every(values.containsKey)) {
      throw const BackupException('Restore records are incomplete.');
    }
    final db = await _open();
    try {
      final done = Completer<void>();
      final tx = db.transaction('records'.toJS, 'readwrite');
      tx.oncomplete = ((web.Event _) => done.complete()).toJS;
      void fail(web.Event _) {
        if (!done.isCompleted)
          done.completeError(const BackupException(
              'Restore could not be saved. Existing records were retained.'));
      }

      tx.onerror = fail.toJS;
      tx.onabort = fail.toJS;
      final store = tx.objectStore('records');
      for (final key in CoreBackup.keys) {
        store.put(values[key]!.toJS, key.toJS);
      }
      await done.future;
    } finally {
      db.close();
    }
  }
}
