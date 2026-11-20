import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'garment_media_store.dart';
import '../models/clothing_item.dart';
import 'automatic_template_registry.dart';
import 'wardrobe_account.dart';

/// An in-memory preview, never a Supabase identity or a cloud auth bypass.
/// Compiled out of release/profile sign-in paths by the kDebugMode check.
class PreviewSession extends ChangeNotifier {
  static final instance = PreviewSession();
  static const enabled = kDebugMode;
  PreviewAccount? _account;
  PreviewAccount? get account => _account;
  bool get active => _account != null;

  bool signIn(String username, String password) {
    if (!enabled || username != 'username' || password != 'password') return false;
    _account?.close();
    _account = PreviewAccount();
    notifyListeners();
    return true;
  }

  void signOut() {
    _account?.close();
    _account = null;
    notifyListeners();
  }
}

class PreviewAccount implements WardrobeAccount {
  bool _open = true;
  final Map<String, _PreviewDocument> _documents = {};
  void _check() {
    if (!_open) throw StateError('This preview session has ended.');
  }
  @override
  WardrobeDocument document(String kind) {
    _check();
    return _documents.putIfAbsent(kind, () => _PreviewDocument(this));
  }
  void close() {
    _open = false;
    for (final document in _documents.values) { document.value = null; }
    _documents.clear();
  }
}

class _PreviewDocument implements WardrobeDocument {
  _PreviewDocument(this.account);
  final PreviewAccount account;
  String? value;
  @override
  Future<String?> read() async { account._check(); return value; }
  @override
  Future<void> write(String value) async { account._check(); this.value = value; }
}

/// Exactly one catalogue item per approved style. Uses the original GLB bytes;
/// no photo upload, AI classification, review, wear history or RFID is invented.
String previewAssetPath(String original) {
  final slash = original.lastIndexOf('/');
  return '${original.substring(0, slash + 1)}preview_neutral_v5_${original.substring(slash + 1)}';
}

String previewColor(GarmentCategory category) =>
    clothingTypeForRole(layerRoleForCategory(category)) == ClothingType.top
        ? '#C9BBA6' : '#55585C';

List<ClothingItem> previewGarments() {
  final now = DateTime.now().toUtc();
  return finishedGarmentStyles.map((style) => ClothingItem(
    id: 'preview_${style.profile}_${style.key}',
    name: style.label,
    colorLabel: previewColor(style.category),
    source: GarmentSource(type: GarmentSourceType.catalogue,
        createdAt: now, updatedAt: now),
    classification: GarmentClassification(category: style.category,
        source: DataSource.catalogue),
    attributes: GarmentAttributes(layerRole: layerRoleForCategory(style.category),
        primaryColor: previewColor(style.category), pattern: GarmentPattern.solid),
    digital3D: Digital3DAsset(status: AssetStatus.ready,
        provider: 'catalogue_preview', format: 'glb', assetUrl: previewAssetPath(style.assetPath)),
    bodyCompatibility: BodyCompatibility(canonicalProfiles: [style.profile],
        fitVariants: {style.profile: previewAssetPath(style.assetPath)}),
  )).toList(growable: false);
}

/// Immutable references keep successive test uploads from reusing a cached GLB.
class PreviewGarmentMediaStore extends MemoryGarmentMediaStore {
  int _revision = 0;
  @override
  Future<String> put(String garmentId, String kind, Uint8List bytes) async {
    final reference = 'memory://$garmentId/$kind/${_revision++}';
    values[reference] = Uint8List.fromList(bytes);
    return reference;
  }
}
