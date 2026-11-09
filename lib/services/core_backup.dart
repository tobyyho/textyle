import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/clothing_item.dart';
import '../models/outfit_record.dart';
import '../models/outfit_activity_store.dart';
import 'garment_media_store.dart';

abstract interface class CoreBackupRecords {
  Future<Map<String, String?>> readAll();
  Future<void> replaceAll(Map<String, String> values);
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A bounded JSON container. Media bytes are base64 with SHA-256; no code or
/// arbitrary archive paths are interpreted. This is a CORE backup, not a
/// general browser-profile or account backup.
class CoreBackup {
  CoreBackup({required this.records, required this.media});

  static const int schemaVersion = 1;
  static const int maxArchiveBytes = 128 * 1024 * 1024;
  static const int maxMediaBytes = 80 * 1024 * 1024;
  static const int maxSingleMediaBytes = 32 * 1024 * 1024;
  static const int maxGarments = 3000;
  static const int maxMediaEntries = 12000;
  static const inventoryKey = 'textyle.wardrobe.v2';
  static const outfitsKey = 'textyle.outfits.v1';
  static const activityKey = 'textyle.outfit-activity.v1';
  static const keys = [inventoryKey, outfitsKey, activityKey];

  final CoreBackupRecords records;
  final GarmentMediaStore media;

  Future<Uint8List> export() async {
    final values = await records.readAll();
    final validated = _validateRecords(values);
    final references = _references(validated.inventory);
    if (references.length > maxMediaEntries) {
      throw const BackupException('Too many media entries to export.');
    }
    final assets = <String, Map<String, Object?>>{};
    final rawAssets = <String, Uint8List>{};
    var total = 0;
    for (final reference in references) {
      final bytes = await media.get(reference);
      if (bytes == null) {
        throw BackupException('A garment asset is missing: $reference');
      }
      if (bytes.length > maxSingleMediaBytes) {
        throw const BackupException(
            'One garment asset exceeds the backup limit.');
      }
      total += bytes.length;
      if (total > maxMediaBytes) {
        throw const BackupException('Garment media exceeds the backup limit.');
      }
      assets[reference] = {
        'size': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'base64': base64Encode(bytes),
      };
      rawAssets[reference] = bytes;
    }
    _verifyKnownHashes(validated.inventory, rawAssets);
    final after = await records.readAll();
    if (keys.any((key) => values[key] != after[key])) {
      throw const BackupException(
          'Wardrobe data changed during export. Please retry.');
    }
    final payload = {
      'format': 'textyle-core-backup',
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'records': {for (final key in keys) key: values[key] ?? _empty(key)},
      'media': assets,
      'bundledCatalogueAssets': _bundledCatalogueAssets(validated.inventory),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    if (bytes.length > maxArchiveBytes) {
      throw const BackupException('The backup exceeds the 128 MiB limit.');
    }
    return bytes;
  }

  /// Validate everything before any write. Media is then staged under fresh
  /// references. The three record keys switch in one IndexedDB transaction.
  /// A failed staging/write leaves existing records and media untouched.
  Future<void> restore(Uint8List archive) async {
    final parsed = parse(archive);
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final remap = <String, String>{};
    var index = 0;
    for (final entry in parsed.media.entries) {
      final staged =
          await media.put('core-restore-$token', '${index++}', entry.value);
      remap[entry.key] = staged;
    }
    final inventory = _rewrite(parsed.inventory, remap) as List<Object?>;
    final replacement = {
      inventoryKey: jsonEncode(inventory),
      outfitsKey: jsonEncode(parsed.outfits),
      activityKey: jsonEncode(parsed.activity),
    };
    await records.replaceAll(replacement);
  }

  static ParsedCoreBackup parse(Uint8List archive) {
    if (archive.isEmpty || archive.length > maxArchiveBytes) {
      throw const BackupException('Backup file is empty or exceeds 128 MiB.');
    }
    late final Map<String, Object?> root;
    try {
      root = Map<String, Object?>.from(jsonDecode(utf8.decode(archive)) as Map);
    } on Object {
      throw const BackupException('Backup is not valid UTF-8 JSON.');
    }
    if (root['format'] != 'textyle-core-backup' ||
        root['schemaVersion'] != schemaVersion) {
      throw const BackupException(
          'Unsupported Textyle backup format or version.');
    }
    final rawRecords = root['records'];
    final rawMedia = root['media'];
    if (rawRecords is! Map || rawMedia is! Map) {
      throw const BackupException(
          'Backup records or media manifest is missing.');
    }
    if (rawRecords.length != keys.length || rawMedia.length > maxMediaEntries) {
      throw const BackupException(
          'Backup contains unexpected records or too much media.');
    }
    final values = <String, String?>{};
    for (final key in keys) {
      if (rawRecords[key] is! String) {
        throw BackupException('Backup is missing $key.');
      }
      values[key] = rawRecords[key] as String;
    }
    final validated = _validateRecords(values);
    final expectedBundled = _bundledCatalogueAssets(validated.inventory);
    final bundled = root['bundledCatalogueAssets'];
    if (bundled is! List ||
        bundled.length != expectedBundled.length ||
        !bundled.every(
            (item) => item is String && expectedBundled.contains(item))) {
      throw const BackupException(
          'Bundled catalogue asset manifest is invalid.');
    }
    final references = _references(validated.inventory);
    if (references.length != rawMedia.length ||
        !references.every(rawMedia.containsKey)) {
      throw const BackupException(
          'Backup media references do not match its manifest.');
    }
    final media = <String, Uint8List>{};
    var total = 0;
    for (final reference in references) {
      final value = rawMedia[reference];
      if (value is! Map) {
        throw const BackupException('A media manifest entry is malformed.');
      }
      final item = Map<String, Object?>.from(value);
      if (item['size'] is! int ||
          item['sha256'] is! String ||
          item['base64'] is! String) {
        throw const BackupException('A media manifest entry is incomplete.');
      }
      late final Uint8List bytes;
      try {
        bytes = base64Decode(item['base64'] as String);
      } on Object {
        throw const BackupException('A media entry is not valid base64.');
      }
      if (bytes.length != item['size'] ||
          bytes.length > maxSingleMediaBytes ||
          sha256.convert(bytes).toString() != item['sha256']) {
        throw const BackupException(
            'A media entry failed size or SHA-256 validation.');
      }
      total += bytes.length;
      if (total > maxMediaBytes) {
        throw const BackupException('Backup media exceeds the 80 MiB limit.');
      }
      media[reference] = bytes;
    }
    _verifyKnownHashes(validated.inventory, media);
    return ParsedCoreBackup(
        validated.inventory, validated.outfits, validated.activity, media);
  }

  static _Validated _validateRecords(Map<String, String?> values) {
    late final List<Object?> inventory;
    late final List<Object?> outfits;
    late final Map<String, Object?> activity;
    try {
      inventory = List<Object?>.from(
          jsonDecode(values[inventoryKey] ?? _empty(inventoryKey)) as List);
      outfits = List<Object?>.from(
          jsonDecode(values[outfitsKey] ?? _empty(outfitsKey)) as List);
      activity = Map<String, Object?>.from(
          jsonDecode(values[activityKey] ?? _empty(activityKey)) as Map);
    } on Object {
      throw const BackupException(
          'Wardrobe, outfit or activity records are malformed.');
    }
    if (inventory.length > maxGarments ||
        outfits.length > 10000 ||
        activity['schemaVersion'] != 1 ||
        activity['plans'] is! List ||
        activity['wears'] is! List) {
      throw const BackupException('Unsupported or oversized CORE records.');
    }
    _rejectCredentialFields(inventory);
    _rejectCredentialFields(outfits);
    _rejectCredentialFields(activity);
    final garmentIds = <String>{};
    for (final raw in inventory) {
      try {
        final map = Map<String, Object?>.from(raw as Map);
        if (map['schemaVersion'] != ClothingItem.schemaVersion) {
          throw const BackupException('Unsupported garment schema.');
        }
        final item = ClothingItem.fromJson(map);
        if (item.id.isEmpty || !garmentIds.add(item.id)) {
          throw const BackupException('Duplicate or empty garment ID.');
        }
        _checkUnsupportedAssets(map);
      } on BackupException {
        rethrow;
      } on Object {
        throw const BackupException('A garment record is malformed.');
      }
    }
    final outfitIds = <String>{};
    for (final raw in outfits) {
      try {
        final item =
            OutfitRecord.fromJson(Map<String, Object?>.from(raw as Map));
        if (item.id.isEmpty || !outfitIds.add(item.id)) {
          throw const BackupException('Duplicate or empty outfit ID.');
        }
        final roleIds = item.garmentByRole.values.toSet();
        if (roleIds.length != item.garmentByRole.length ||
            !roleIds.containsAll(item.garmentIds) ||
            !item.garmentIds.toSet().containsAll(roleIds) ||
            !roleIds.every(garmentIds.contains)) {
          throw const BackupException(
              'An outfit has inconsistent or missing garment references.');
        }
        // A top-only or bottom-only outfit is still readable but incomplete.
      } on BackupException {
        rethrow;
      } on Object {
        throw const BackupException('An outfit record is malformed.');
      }
    }
    try {
      final plans = activity['plans'] as List;
      final wears = activity['wears'] as List;
      if (plans.length > 10000 || wears.length > 100000) {
        throw const BackupException('Activity history is too large.');
      }
      final dates = <String>{};
      for (final raw in plans) {
        final map = Map<String, Object?>.from(raw as Map);
        CivilDate.parse(map['date'] as String);
        if (!dates.add(map['date'] as String) || map['outfitId'] is! String) {
          throw const BackupException('Invalid or duplicate plan date.');
        }
      }
      final wearPairs = <String>{};
      final wearIds = <String>{};
      for (final raw in wears) {
        final map = Map<String, Object?>.from(raw as Map);
        CivilDate.parse(map['date'] as String);
        if (map['id'] is! String ||
            (map['id'] as String).isEmpty ||
            !wearIds.add(map['id'] as String) ||
            map['outfitId'] is! String ||
            map['outfitNameSnapshot'] is! String ||
            !wearPairs.add('${map['date']}:${map['outfitId']}')) {
          throw const BackupException('Invalid or duplicate wear event.');
        }
      }
    } on BackupException {
      rethrow;
    } on Object {
      throw const BackupException('Activity records are malformed.');
    }
    return _Validated(inventory, outfits, activity);
  }

  static void _rejectCredentialFields(Object? value) {
    const forbidden = {
      'apikey',
      'x-api-key',
      'authorization',
      'accesstoken',
      'refreshtoken',
      'password',
      'clientsecret',
      'secret',
    };
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll('_', '');
        if (forbidden.contains(key)) {
          throw const BackupException(
              'CORE records contain a credential field; export was stopped.');
        }
        _rejectCredentialFields(entry.value);
      }
    } else if (value is List) {
      for (final item in value) {
        _rejectCredentialFields(item);
      }
    }
  }

  static void _verifyKnownHashes(
      List<Object?> inventory, Map<String, Uint8List> assets) {
    void check(Object? ref, Object? expected) {
      if (ref is! String ||
          expected is! String ||
          expected.isEmpty ||
          !_localRef(ref)) return;
      final bytes = assets[ref];
      if (bytes == null || sha256.convert(bytes).toString() != expected) {
        throw const BackupException(
            'A garment asset conflicts with its recorded SHA-256.');
      }
    }

    for (final raw in inventory) {
      final garment = raw as Map;
      final media = garment['media'];
      if (media is Map) {
        check(media['wornOriginal'], media['wornOriginalHash']);
        check(media['frontIntentCrop'], media['intentCropHash']);
        final views = media['views'];
        if (views is Map) {
          for (final view in ['front', 'back']) {
            final detail = views[view];
            final identity = detail is Map ? detail['identity'] : null;
            if (identity is! Map) continue;
            final prefix = view == 'front' ? 'front' : 'back';
            check(media['${prefix}Original'], identity['source_image_sha256']);
            check(media['${prefix}Normalized'],
                identity['normalized_image_sha256']);
            check(media['${prefix}Mask'], identity['mask_sha256']);
          }
        }
      }
      final digital = garment['digital3D'];
      if (digital is Map) {
        check(digital['assetUrl'], digital['glbSha256']);
        check(digital['sourceAssetUrl'], digital['sidecarSha256']);
        if (digital['status'] == 'ready' &&
            digital['assetUrl'] is String &&
            _localRef(digital['assetUrl'] as String)) {
          final glb = assets[digital['assetUrl'] as String];
          if (glb == null ||
              glb.length < 12 ||
              glb[0] != 0x67 ||
              glb[1] != 0x6c ||
              glb[2] != 0x54 ||
              glb[3] != 0x46) {
            throw const BackupException(
                'A local 3D asset is not a valid GLB container.');
          }
          final sidecar = assets[digital['sourceAssetUrl']];
          try {
            if (sidecar == null || jsonDecode(utf8.decode(sidecar)) is! Map) {
              throw const FormatException('Invalid sidecar');
            }
          } on Object {
            throw const BackupException(
                'A local 3D sidecar is not valid JSON.');
          }
        }
      }
    }
  }

  static void _checkUnsupportedAssets(Map<String, Object?> garment) {
    final digital = garment['digital3D'];
    if (digital is Map && digital['status'] == 'ready') {
      final asset = digital['assetUrl'];
      final sidecar = digital['sourceAssetUrl'];
      final isBundledCatalogue =
          (garment['source'] as Map?)?['type'] == 'catalogue' &&
              asset is String &&
              asset.startsWith('assets/clothing/') &&
              sidecar == null;
      if (!isBundledCatalogue &&
          (asset is! String ||
              !_localRef(asset) ||
              sidecar is! String ||
              !_localRef(sidecar))) {
        throw const BackupException(
            'A ready 3D asset is not locally backed and cannot be exported safely.');
      }
    }
    final media = garment['media'];
    if (media is Map) {
      for (final key in [
        'frontOriginal',
        'wornOriginal',
        'frontIntentCrop',
        'backOriginal',
        'frontNormalized',
        'backNormalized',
        'frontMask',
        'backMask'
      ]) {
        final ref = media[key];
        if (ref != null && ref is String && ref.isNotEmpty && !_localRef(ref)) {
          throw BackupException('Unsupported media reference in $key.');
        }
      }
    }
  }

  static List<String> _bundledCatalogueAssets(List<Object?> inventory) {
    final assets = <String>{};
    for (final raw in inventory) {
      final item = raw as Map;
      if ((item['source'] as Map?)?['type'] != 'catalogue') continue;
      final digital = item['digital3D'];
      if (digital is Map &&
          digital['status'] == 'ready' &&
          digital['assetUrl'] is String &&
          (digital['assetUrl'] as String).startsWith('assets/clothing/')) {
        assets.add(digital['assetUrl'] as String);
      }
    }
    return assets.toList()..sort();
  }

  static Set<String> _references(Object? value) {
    final found = <String>{};
    void scan(Object? node) {
      if (node is String && _localRef(node)) found.add(node);
      if (node is List)
        for (final item in node) {
          scan(item);
        }
      if (node is Map)
        for (final item in node.values) {
          scan(item);
        }
    }

    scan(value);
    return found;
  }

  static Object? _rewrite(Object? value, Map<String, String> remap) {
    if (value is String) return remap[value] ?? value;
    if (value is List) return value.map((v) => _rewrite(v, remap)).toList();
    if (value is Map)
      return value.map((k, v) => MapEntry(k.toString(), _rewrite(v, remap)));
    return value;
  }

  static bool _localRef(String value) =>
      value.startsWith('indexeddb://') || value.startsWith('memory://');
  static String _empty(String key) =>
      key == activityKey ? '{"schemaVersion":1,"plans":[],"wears":[]}' : '[]';
}

class ParsedCoreBackup {
  const ParsedCoreBackup(
      this.inventory, this.outfits, this.activity, this.media);
  final List<Object?> inventory;
  final List<Object?> outfits;
  final Map<String, Object?> activity;
  final Map<String, Uint8List> media;
}

class _Validated {
  const _Validated(this.inventory, this.outfits, this.activity);
  final List<Object?> inventory;
  final List<Object?> outfits;
  final Map<String, Object?> activity;
}
