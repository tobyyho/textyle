import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'wardrobe_account.dart';
import 'account_scope.dart';
import 'garment_media_store.dart';

class CloudAccount implements WardrobeAccount {
  CloudAccount(this.client, this.userId)
      : scope = AccountScope(userId, () => client.auth.currentUser?.id);
  final SupabaseClient client;
  final String userId;
  final AccountScope scope;
  final Map<String, CloudDocumentPersistence> _documents = {};
  CloudDocumentPersistence document(String kind) =>
      _documents.putIfAbsent(kind, () => CloudDocumentPersistence(this, kind));
}

/// RLS enforces ownership on the server; the scope guard also blocks stale UI
/// operations after an account switch. Revision checks prevent lost updates.
class CloudDocumentPersistence implements WardrobeDocument {
  CloudDocumentPersistence(this.account, this.kind);
  final CloudAccount account;
  final String kind;
  int _revision = 0;
  bool _loaded = false;
  String? _value;
  Future<void> _writes = Future<void>.value();

  @override
  Future<String?> read() async {
    account.scope.check();
    if (_loaded) return _value;
    final row = await account.client.from('textyle_documents').select('payload,revision')
        .eq('user_id', account.userId).eq('kind', kind).maybeSingle();
    account.scope.check();
    _revision = row == null ? 0 : (row['revision'] as num).toInt();
    _value = row == null ? null : jsonEncode(row['payload']);
    _loaded = true;
    return _value;
  }

  @override
  Future<void> write(String value) {
    final baseRevision = _loaded ? _revision : null;
    final next = _writes.then((_) async {
      account.scope.check();
      if (!_loaded) await read();
      if (baseRevision != null && baseRevision != _revision) {
        throw StateError('An earlier save completed while this change was pending. Reload before retrying.');
      }
      final revision = await account.client.rpc('textyle_write_document', params: {
        'p_kind': kind, 'p_payload': jsonDecode(value), 'p_expected_revision': _revision,
      });
      account.scope.check();
      _revision = (revision as num).toInt();
      _value = value;
    });
    _writes = next.catchError((Object _) {});
    return next;
  }
}

/// Photos, masks and GLBs are private objects, downloaded with the user's JWT.
/// Records contain owner-qualified opaque references, never public asset URLs.
class CloudGarmentMediaStore implements GarmentMediaStore {
  CloudGarmentMediaStore(this.account);
  static const bucket = 'textyle-private-media';
  final CloudAccount account;
  final Map<String, Future<Uint8List?>> _downloads = {};
  final Random _random = Random.secure();

  @override
  Future<String> put(String garmentId, String kind, Uint8List bytes) async {
    account.scope.check();
    if (![garmentId,kind].every((v) => RegExp(r'^[a-zA-Z0-9_-]{1,180}$').hasMatch(v))) {
      throw const FormatException('Invalid garment asset name.');
    }
    final nonce = List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2,'0')).join();
    final digest = sha256.convert(bytes).toString();
    final path = '${account.userId}/$garmentId/$kind-$digest-$nonce.bin';
    await account.client.storage.from(bucket).uploadBinary(path, bytes,
      fileOptions: const FileOptions(contentType: 'application/octet-stream', upsert: false));
    account.scope.check();
    final reference = 'cloudmedia://$path';
    _downloads[reference] = Future.value(Uint8List.fromList(bytes));
    return reference;
  }

  @override
  Future<Uint8List?> get(String reference) async {
    final path = account.scope.mediaPath(reference);
    try {
      final bytes = await _downloads.putIfAbsent(reference, () async {
        final data = await account.client.storage.from(bucket).download(path);
        account.scope.check();
        return data;
      });
      account.scope.check();
      return bytes;
    } catch (_) {
      _downloads.remove(reference);
      rethrow;
    }
  }
  void clear() => _downloads.clear();
}
