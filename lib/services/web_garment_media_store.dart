import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'garment_media_store.dart';

class WebGarmentMediaStore implements GarmentMediaStore {
  static const _databaseName = 'textyle.garment-media.v1';
  static const _storeName = 'assets';
  Future<web.IDBDatabase>? _database;

  Future<web.IDBDatabase> _open() {
    return _database ??= (() {
      final completer = Completer<web.IDBDatabase>();
      final request = web.window.indexedDB.open(_databaseName, 1);
      request.onupgradeneeded = ((web.Event event) {
        final database = request.result as web.IDBDatabase;
        if (!database.objectStoreNames.contains(_storeName)) {
          database.createObjectStore(_storeName);
        }
      }).toJS;
      request.onsuccess = ((web.Event event) {
        completer.complete(request.result as web.IDBDatabase);
      }).toJS;
      request.onerror = ((web.Event event) {
        completer.completeError(
            StateError('IndexedDB media storage is unavailable.'));
      }).toJS;
      return completer.future;
    })();
  }

  Future<JSAny?> _complete(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess =
        ((web.Event event) => completer.complete(request.result)).toJS;
    request.onerror = ((web.Event event) => completer
        .completeError(StateError('IndexedDB media operation failed.'))).toJS;
    return completer.future;
  }

  @override
  Future<String> put(String garmentId, String kind, Uint8List bytes) async {
    final reference = 'indexeddb://$garmentId/$kind';
    final database = await _open();
    final transaction = database.transaction(_storeName.toJS, 'readwrite');
    final committed = Completer<void>();
    transaction.oncomplete = ((web.Event _) => committed.complete()).toJS;
    transaction.onabort = ((web.Event _) =>
        committed.completeError(StateError('Media transaction aborted.'))).toJS;
    transaction.onerror = ((web.Event _) {
      if (!committed.isCompleted)
        committed.completeError(StateError('Media transaction failed.'));
    }).toJS;
    transaction.objectStore(_storeName).put(bytes.toJS, reference.toJS);
    await committed.future;
    return reference;
  }

  @override
  Future<Uint8List?> get(String reference) async {
    if (!reference.startsWith('indexeddb://')) return null;
    final database = await _open();
    final transaction = database.transaction(_storeName.toJS, 'readonly');
    final value = await _complete(
        transaction.objectStore(_storeName).get(reference.toJS));
    try {
      return value == null ? null : (value as JSUint8Array).toDart;
    } on Object {
      return null;
    }
  }
}
