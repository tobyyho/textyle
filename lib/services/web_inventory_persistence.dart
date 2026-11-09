import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../models/inventory_store.dart';

/// Canonical records in IndexedDB; legacy localStorage is read-only fallback.
class WebInventoryPersistence implements InventoryPersistence {
  static const _key = 'textyle.wardrobe.v2';
  Future<web.IDBDatabase> _open() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open('textyle.wardrobe-records.v1', 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore('records');
    }).toJS;
    request.onsuccess = ((web.Event _) =>
        completer.complete(request.result as web.IDBDatabase)).toJS;
    request.onerror = ((web.Event _) => completer
        .completeError(StateError('Wardrobe database unavailable.'))).toJS;
    return completer.future;
  }

  @override
  Future<String?> read() async {
    final database = await _open();
    try {
      final completer = Completer<String?>();
      final request = database
          .transaction('records'.toJS, 'readonly')
          .objectStore('records')
          .get(_key.toJS);
      request.onsuccess = ((web.Event _) {
        final value = request.result;
        completer.complete(value == null
            ? web.window.localStorage.getItem(_key)
            : (value as JSString).toDart);
      }).toJS;
      request.onerror = ((web.Event _) =>
          completer.completeError(StateError('Wardrobe read failed.'))).toJS;
      return await completer.future;
    } finally {
      database.close();
    }
  }

  @override
  Future<void> write(String value) async {
    final database = await _open();
    try {
      final completer = Completer<void>();
      final transaction = database.transaction('records'.toJS, 'readwrite');
      transaction.oncomplete = ((web.Event _) => completer.complete()).toJS;
      void fail(web.Event _) {
        if (!completer.isCompleted)
          completer.completeError(StateError('Wardrobe save failed.'));
      }

      transaction.onerror = fail.toJS;
      transaction.onabort = fail.toJS;
      transaction.objectStore('records').put(value.toJS, _key.toJS);
      await completer.future;
    } finally {
      database.close();
    }
  }
}
