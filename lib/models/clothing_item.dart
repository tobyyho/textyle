enum ClothingType { top, bottom, accessory }

enum GarmentSourceType { userCapture, catalogue, imported, generated, unknown }

enum GarmentCaptureMode { wornMobile, controlledEnrollment, legacy, unknown }

enum ClassificationInput { userSelectedCrop, originalImage, unknown }

enum GarmentCategory {
  shortSleeveTop,
  longSleeveTop,
  sleevelessTop,
  outerwear,
  shorts,
  trousers,
  skirt,
  dress,
  unknown
}

enum SleeveType { shortSleeve, longSleeve, sleeveless, notApplicable, unknown }

enum LayerRole {
  top,
  bottom,
  onePiece,
  outerwear,
  accessory,
  footwear,
  unknown
}

enum Season { spring, summer, fall, winter }

enum GarmentPattern {
  solid,
  striped,
  checkedOrPlaid,
  floral,
  graphicOrPrinted,
  other,
  unknown
}

enum AssetStatus { notGenerated, queued, processing, ready, failed, stale }

enum DataSource {
  user,
  tailor,
  externalAi,
  catalogue,
  generatedEstimate,
  systemDefault,
  unknown
}

String enumWire(Enum value) => value.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '_${match[1]!.toLowerCase()}',
    );

T enumFromWire<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.firstWhere((value) => enumWire(value) == raw?.toString(),
        orElse: () => fallback);

LayerRole layerRoleForCategory(GarmentCategory category) => switch (category) {
      GarmentCategory.shortSleeveTop ||
      GarmentCategory.longSleeveTop ||
      GarmentCategory.sleevelessTop =>
        LayerRole.top,
      GarmentCategory.outerwear => LayerRole.outerwear,
      GarmentCategory.shorts ||
      GarmentCategory.trousers ||
      GarmentCategory.skirt =>
        LayerRole.bottom,
      GarmentCategory.dress => LayerRole.onePiece,
      GarmentCategory.unknown => LayerRole.unknown,
    };

ClothingType clothingTypeForRole(LayerRole role) => switch (role) {
      LayerRole.top || LayerRole.outerwear => ClothingType.top,
      LayerRole.bottom || LayerRole.onePiece => ClothingType.bottom,
      _ => ClothingType.accessory,
    };

class ProvenanceValue<T> {
  final T? value;
  final DataSource source;
  final double? confidence;
  final bool userConfirmed;

  const ProvenanceValue({
    this.value,
    this.source = DataSource.unknown,
    this.confidence,
    this.userConfirmed = false,
  });

  Map<String, Object?> toJson(Object? Function(T value) encode) => {
        'value': value == null ? null : encode(value as T),
        'source': enumWire(source),
        'confidence': confidence,
        'userConfirmed': userConfirmed,
      };
}

class GarmentSource {
  final GarmentSourceType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GarmentSource(
      {required this.type, required this.createdAt, required this.updatedAt});

  Map<String, Object?> toJson() => {
        'type': enumWire(type),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory GarmentSource.fromJson(Map<String, Object?> json) {
    final now = DateTime.now().toUtc();
    return GarmentSource(
      type: enumFromWire(
          GarmentSourceType.values, json['type'], GarmentSourceType.unknown),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? now,
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? now,
    );
  }
}

class GarmentClassification {
  final GarmentCategory category;
  final double? confidence;
  final bool abstained;
  final String? modelVersion;
  final bool userConfirmed;
  final DataSource source;
  final ClassificationInput input;

  const GarmentClassification({
    required this.category,
    this.confidence,
    this.abstained = false,
    this.modelVersion,
    this.userConfirmed = false,
    this.source = DataSource.unknown,
    this.input = ClassificationInput.unknown,
  });

  Map<String, Object?> toJson() => {
        'category': enumWire(category),
        'confidence': confidence,
        'abstained': abstained,
        'modelVersion': modelVersion,
        'userConfirmed': userConfirmed,
        'source': enumWire(source),
        'input': enumWire(input),
      };

  factory GarmentClassification.fromJson(Map<String, Object?> json) =>
      GarmentClassification(
        category: enumFromWire(
            GarmentCategory.values, json['category'], GarmentCategory.unknown),
        confidence: (json['confidence'] as num?)?.toDouble(),
        abstained: json['abstained'] == true,
        modelVersion: json['modelVersion']?.toString(),
        userConfirmed: json['userConfirmed'] == true,
        source:
            enumFromWire(DataSource.values, json['source'], DataSource.unknown),
        input: enumFromWire(ClassificationInput.values, json['input'],
            ClassificationInput.unknown),
      );
}

class GarmentAttributes {
  final SleeveType sleeveType;
  final String? primaryColor;
  final List<String> secondaryColors;
  final GarmentPattern? pattern;
  final Set<Season> seasons;
  final LayerRole layerRole;
  final Map<String, ProvenanceValue<String>> provenance;

  const GarmentAttributes({
    this.sleeveType = SleeveType.unknown,
    this.primaryColor,
    this.secondaryColors = const [],
    this.pattern,
    this.seasons = const {},
    this.layerRole = LayerRole.unknown,
    this.provenance = const {},
  });

  Map<String, Object?> toJson() => {
        'sleeveType': enumWire(sleeveType),
        'primaryColor': primaryColor,
        'secondaryColors': secondaryColors,
        'pattern': pattern == null ? null : enumWire(pattern!),
        'seasons': seasons.map(enumWire).toList()..sort(),
        'layerRole': enumWire(layerRole),
        'provenance': provenance.map(
          (key, value) => MapEntry(key, value.toJson((item) => item)),
        ),
      };

  factory GarmentAttributes.fromJson(Map<String, Object?> json) {
    final rawProvenance = json['provenance'];
    return GarmentAttributes(
      sleeveType: enumFromWire(
          SleeveType.values, json['sleeveType'], SleeveType.unknown),
      primaryColor: json['primaryColor']?.toString(),
      secondaryColors: (json['secondaryColors'] as List? ?? const [])
          .map((v) => '$v')
          .toList(),
      pattern: json['pattern'] == null
          ? null
          : enumFromWire(
              GarmentPattern.values, json['pattern'], GarmentPattern.unknown),
      seasons: (json['seasons'] as List? ?? const [])
          .map((v) => enumFromWire(Season.values, v, Season.spring))
          .toSet(),
      layerRole:
          enumFromWire(LayerRole.values, json['layerRole'], LayerRole.unknown),
      provenance: rawProvenance is Map
          ? rawProvenance.map((key, value) {
              final map = Map<String, Object?>.from(value as Map);
              return MapEntry(
                '$key',
                ProvenanceValue<String>(
                  value: map['value']?.toString(),
                  source: enumFromWire(
                      DataSource.values, map['source'], DataSource.unknown),
                  confidence: (map['confidence'] as num?)?.toDouble(),
                  userConfirmed: map['userConfirmed'] == true,
                ),
              );
            })
          : const {},
    );
  }
}

class GarmentMedia {
  final Map<String, Object?> views;
  final String? frontOriginal;
  final String? wornOriginal;
  final String? wornOriginalHash;
  final String? frontIntentCrop;
  final String? intentCropHash;
  final List<double>? intentBox;
  final String? backOriginal;
  final String? frontNormalized;
  final String? backNormalized;
  final String? frontMask;
  final String? backMask;
  final String assetVersion;
  final String? sourceImageHash;
  final String? normalizedImageHash;
  final String? maskHash;
  final String? processorVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GarmentMedia({
    this.views = const {},
    this.frontOriginal,
    this.wornOriginal,
    this.wornOriginalHash,
    this.frontIntentCrop,
    this.intentCropHash,
    this.intentBox,
    this.backOriginal,
    this.frontNormalized,
    this.backNormalized,
    this.frontMask,
    this.backMask,
    this.assetVersion = '1',
    this.sourceImageHash,
    this.normalizedImageHash,
    this.maskHash,
    this.processorVersion,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, Object?> toJson() => {
        'frontOriginal': frontOriginal,
        'wornOriginal': wornOriginal,
        'wornOriginalHash': wornOriginalHash,
        'frontIntentCrop': frontIntentCrop,
        'intentCropHash': intentCropHash,
        'intentBox': intentBox,
        'views': views,
        'backOriginal': backOriginal,
        'frontNormalized': frontNormalized,
        'backNormalized': backNormalized,
        'frontMask': frontMask,
        'backMask': backMask,
        'assetVersion': assetVersion,
        'sourceImageHash': sourceImageHash,
        'normalizedImageHash': normalizedImageHash,
        'maskHash': maskHash,
        'processorVersion': processorVersion,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory GarmentMedia.fromJson(Map<String, Object?> json) => GarmentMedia(
        views: json['views'] is Map
            ? Map<String, Object?>.from(json['views'] as Map)
            : const {},
        frontOriginal: json['frontOriginal']?.toString(),
        wornOriginal: json['wornOriginal']?.toString(),
        wornOriginalHash: json['wornOriginalHash']?.toString(),
        frontIntentCrop: json['frontIntentCrop']?.toString(),
        intentCropHash: json['intentCropHash']?.toString(),
        intentBox: (json['intentBox'] as List?)
            ?.map((value) => (value as num).toDouble())
            .toList(),
        backOriginal: json['backOriginal']?.toString(),
        frontNormalized: json['frontNormalized']?.toString(),
        backNormalized: json['backNormalized']?.toString(),
        frontMask: json['frontMask']?.toString(),
        backMask: json['backMask']?.toString(),
        assetVersion: json['assetVersion']?.toString() ?? '1',
        sourceImageHash: json['sourceImageHash']?.toString(),
        normalizedImageHash: json['normalizedImageHash']?.toString(),
        maskHash: json['maskHash']?.toString(),
        processorVersion: json['processorVersion']?.toString(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
        updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
      );
}

class AiReadiness {
  final bool classificationReady;
  final bool segmentationReady;
  final bool tryOnReady;
  final bool threeDReady;

  const AiReadiness({
    this.classificationReady = false,
    this.segmentationReady = false,
    this.tryOnReady = false,
    this.threeDReady = false,
  });

  Map<String, Object?> toJson() => {
        'classificationReady': classificationReady,
        'segmentationReady': segmentationReady,
        'tryOnReady': tryOnReady,
        'threeDReady': threeDReady,
      };

  factory AiReadiness.fromJson(Map<String, Object?> json) => AiReadiness(
        classificationReady: json['classificationReady'] == true,
        segmentationReady: json['segmentationReady'] == true,
        tryOnReady: json['tryOnReady'] == true,
        threeDReady: json['threeDReady'] == true,
      );
}

class VirtualTryOnAsset {
  final AssetStatus status;
  final String? provider;
  final String? assetVersion;
  final String? previewUrl;

  const VirtualTryOnAsset({
    this.status = AssetStatus.notGenerated,
    this.provider,
    this.assetVersion,
    this.previewUrl,
  });

  Map<String, Object?> toJson() => {
        'status': enumWire(status),
        'provider': provider,
        'assetVersion': assetVersion,
        'previewUrl': previewUrl,
      };

  factory VirtualTryOnAsset.fromJson(Map<String, Object?> json) =>
      VirtualTryOnAsset(
        status: enumFromWire(
            AssetStatus.values, json['status'], AssetStatus.notGenerated),
        provider: json['provider']?.toString(),
        assetVersion: json['assetVersion']?.toString(),
        previewUrl: json['previewUrl']?.toString(),
      );
}

class Digital3DAsset {
  final AssetStatus status;
  final String? provider;
  final String? format;
  final String? assetUrl;
  final String? sourceAssetUrl;
  final String? generationVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool canonicalized;
  final String? canonicalizationVersion;
  final String? assetFingerprint;
  final String? glbSha256;
  final String? sidecarSha256;
  final String? templateVersion;
  final String? sourceImageHash;
  final String? normalizedImageHash;
  final String? maskHash;
  final String? approvalFingerprint;
  final GarmentCategory? sourceCategory;

  const Digital3DAsset({
    this.status = AssetStatus.notGenerated,
    this.provider,
    this.format,
    this.assetUrl,
    this.sourceAssetUrl,
    this.generationVersion,
    this.createdAt,
    this.updatedAt,
    this.canonicalized = false,
    this.canonicalizationVersion,
    this.assetFingerprint,
    this.glbSha256,
    this.sidecarSha256,
    this.templateVersion,
    this.sourceImageHash,
    this.normalizedImageHash,
    this.maskHash,
    this.approvalFingerprint,
    this.sourceCategory,
  });

  Map<String, Object?> toJson() => {
        'status': enumWire(status),
        'provider': provider,
        'format': format,
        'assetUrl': assetUrl,
        'sourceAssetUrl': sourceAssetUrl,
        'generationVersion': generationVersion,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
        'canonicalized': canonicalized,
        'canonicalizationVersion': canonicalizationVersion,
        'assetFingerprint': assetFingerprint,
        'glbSha256': glbSha256,
        'sidecarSha256': sidecarSha256,
        'templateVersion': templateVersion,
        'sourceImageHash': sourceImageHash,
        'normalizedImageHash': normalizedImageHash,
        'maskHash': maskHash,
        'approvalFingerprint': approvalFingerprint,
        'sourceCategory':
            sourceCategory == null ? null : enumWire(sourceCategory!),
      };

  factory Digital3DAsset.fromJson(Map<String, Object?> json) => Digital3DAsset(
        status: enumFromWire(
            AssetStatus.values, json['status'], AssetStatus.notGenerated),
        provider: json['provider']?.toString(),
        format: json['format']?.toString(),
        assetUrl: json['assetUrl']?.toString(),
        sourceAssetUrl: json['sourceAssetUrl']?.toString(),
        generationVersion: json['generationVersion']?.toString(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
        updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
        canonicalized: json['canonicalized'] == true,
        canonicalizationVersion: json['canonicalizationVersion']?.toString(),
        assetFingerprint: json['assetFingerprint']?.toString(),
        glbSha256: json['glbSha256']?.toString(),
        sidecarSha256: json['sidecarSha256']?.toString(),
        templateVersion: json['templateVersion']?.toString(),
        sourceImageHash: json['sourceImageHash']?.toString(),
        normalizedImageHash: json['normalizedImageHash']?.toString(),
        maskHash: json['maskHash']?.toString(),
        approvalFingerprint: json['approvalFingerprint']?.toString(),
        sourceCategory: json['sourceCategory'] == null
            ? null
            : enumFromWire(GarmentCategory.values, json['sourceCategory'],
                GarmentCategory.unknown),
      );
}

class BodyCompatibility {
  final List<String> canonicalProfiles;
  final Map<String, String?> fitVariants;

  const BodyCompatibility(
      {this.canonicalProfiles = const [], this.fitVariants = const {}});

  Map<String, Object?> toJson() => {
        'canonicalProfiles': canonicalProfiles,
        'fitVariants': fitVariants,
      };

  factory BodyCompatibility.fromJson(Map<String, Object?> json) =>
      BodyCompatibility(
        canonicalProfiles: (json['canonicalProfiles'] as List? ?? const [])
            .map((v) => '$v')
            .toList(),
        fitVariants: (json['fitVariants'] as Map? ?? const {})
            .map((key, value) => MapEntry('$key', value?.toString())),
      );
}

class ClothingItem {
  static const int schemaVersion = 2;

  final String id;
  final ClothingType type;
  final String name;
  final String colorLabel;
  final String? originalImagePath;
  final String? inventoryRenderPath;
  final String? avatarRenderPath;
  final bool isProcessed;
  final GarmentSource source;
  final GarmentCaptureMode captureMode;
  final GarmentClassification classification;
  final GarmentAttributes attributes;
  final GarmentMedia media;
  final AiReadiness aiReadiness;
  final VirtualTryOnAsset virtualTryOn;
  final Digital3DAsset digital3D;
  final BodyCompatibility bodyCompatibility;

  ClothingItem({
    required this.id,
    ClothingType? type,
    required this.name,
    this.colorLabel = '',
    this.originalImagePath,
    this.inventoryRenderPath,
    this.avatarRenderPath,
    this.isProcessed = false,
    GarmentSource? source,
    this.captureMode = GarmentCaptureMode.legacy,
    GarmentClassification? classification,
    GarmentAttributes? attributes,
    GarmentMedia? media,
    AiReadiness aiReadiness = const AiReadiness(),
    this.virtualTryOn = const VirtualTryOnAsset(),
    this.digital3D = const Digital3DAsset(),
    this.bodyCompatibility = const BodyCompatibility(),
  })  : source = source ??
            GarmentSource(
                type: GarmentSourceType.unknown,
                createdAt: DateTime.now().toUtc(),
                updatedAt: DateTime.now().toUtc()),
        aiReadiness = captureMode == GarmentCaptureMode.wornMobile
            ? AiReadiness(classificationReady: aiReadiness.classificationReady)
            : aiReadiness,
        classification = classification ??
            const GarmentClassification(
                category: GarmentCategory.unknown,
                userConfirmed: true,
                source: DataSource.user),
        attributes = attributes ?? const GarmentAttributes(),
        media = media ?? GarmentMedia(frontOriginal: originalImagePath),
        type = type ??
            clothingTypeForRole(attributes?.layerRole ?? LayerRole.unknown);

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'type': enumWire(type),
        'name': name,
        'colorLabel': colorLabel,
        'originalImagePath': originalImagePath,
        'inventoryRenderPath': inventoryRenderPath,
        'avatarRenderPath': avatarRenderPath,
        'isProcessed': isProcessed,
        'source': source.toJson(),
        'captureMode': enumWire(captureMode),
        'classification': classification.toJson(),
        'attributes': attributes.toJson(),
        'media': media.toJson(),
        'aiReadiness': aiReadiness.toJson(),
        'virtualTryOn': virtualTryOn.toJson(),
        'digital3D': digital3D.toJson(),
        'bodyCompatibility': bodyCompatibility.toJson(),
      };

  factory ClothingItem.fromJson(Map<String, Object?> json) {
    Map<String, Object?> map(String key) {
      final value = json[key];
      return value is Map
          ? Map<String, Object?>.from(value)
          : <String, Object?>{};
    }

    final legacyType =
        enumFromWire(ClothingType.values, json['type'], ClothingType.accessory);
    final legacyRole = switch (legacyType) {
      ClothingType.top => LayerRole.top,
      ClothingType.bottom => LayerRole.bottom,
      ClothingType.accessory => LayerRole.accessory,
    };
    final classificationJson = map('classification');
    final attributesJson = map('attributes');
    final legacyCategory = legacyType == ClothingType.top
        ? GarmentCategory.shortSleeveTop
        : legacyType == ClothingType.bottom
            ? GarmentCategory.trousers
            : GarmentCategory.unknown;
    final classification = classificationJson.isEmpty
        ? GarmentClassification(
            category: legacyCategory,
            userConfirmed: true,
            source: DataSource.user)
        : GarmentClassification.fromJson(classificationJson);
    final attributes = attributesJson.isEmpty
        ? GarmentAttributes(
            primaryColor: json['colorLabel']?.toString(), layerRole: legacyRole)
        : GarmentAttributes.fromJson(attributesJson);
    final original = json['originalImagePath']?.toString();
    final mediaJson = map('media');

    return ClothingItem(
      id: json['id']?.toString() ?? '',
      type: enumFromWire(ClothingType.values, json['type'],
          clothingTypeForRole(attributes.layerRole)),
      name: json['name']?.toString() ?? 'Untitled garment',
      colorLabel:
          json['colorLabel']?.toString() ?? attributes.primaryColor ?? '',
      originalImagePath: original,
      inventoryRenderPath: json['inventoryRenderPath']?.toString(),
      avatarRenderPath: json['avatarRenderPath']?.toString(),
      isProcessed: json['isProcessed'] == true,
      source: map('source').isEmpty
          ? GarmentSource(
              type: GarmentSourceType.unknown,
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc())
          : GarmentSource.fromJson(map('source')),
      captureMode: enumFromWire(GarmentCaptureMode.values, json['captureMode'],
          GarmentCaptureMode.legacy),
      classification: classification,
      attributes: attributes,
      media: mediaJson.isEmpty
          ? GarmentMedia(frontOriginal: original)
          : GarmentMedia.fromJson(mediaJson),
      aiReadiness: AiReadiness.fromJson(map('aiReadiness')),
      virtualTryOn: VirtualTryOnAsset.fromJson(map('virtualTryOn')),
      digital3D: Digital3DAsset.fromJson(map('digital3D')),
      bodyCompatibility: BodyCompatibility.fromJson(map('bodyCompatibility')),
    );
  }
}
