import '../models/clothing_item.dart';
import 'segmentation_candidate.dart';

class TailorPrediction {
  final GarmentCategory category;
  final double confidence;
  const TailorPrediction({required this.category, required this.confidence});
}

class TailorAnalysis {
  final String requestId;
  final bool abstained;
  final TailorPrediction prediction;
  final List<TailorPrediction> topPredictions;
  final SleeveType sleeveType;
  final List<String> warnings;
  final String modelVersion;

  const TailorAnalysis({required this.requestId, required this.abstained, required this.prediction, required this.topPredictions, required this.sleeveType, required this.warnings, required this.modelVersion});

  factory TailorAnalysis.fromJson(Map<String, Object?> json) {
    final prediction = _map(json['prediction']);
    final attributes = _map(json['derived_attributes']);
    final model = _map(json['model']);
    final top = prediction['top_predictions'];
    if (json['request_id'] is! String || prediction['category'] is! String || prediction['confidence'] is! num || top is! List) {
      throw const FormatException('Unexpected Tailor response');
    }
    TailorPrediction parsePrediction(Object? value) {
      final item = _map(value);
      if (item['category'] is! String || item['confidence'] is! num) throw const FormatException('Malformed Tailor prediction');
      final rawCategory = item['category'] as String;
      final category = enumFromWire(GarmentCategory.values, rawCategory, GarmentCategory.unknown);
      if (enumWire(category) != rawCategory) {
        throw FormatException('Unsupported Tailor category: $rawCategory');
      }
      return TailorPrediction(category: category, confidence: (item['confidence'] as num).toDouble());
    }
    return TailorAnalysis(
      requestId: json['request_id'] as String,
      abstained: prediction['abstained'] == true || json['status'] == 'abstained',
      prediction: parsePrediction(prediction),
      topPredictions: top.map(parsePrediction).toList(),
      sleeveType: enumFromWire(SleeveType.values, attributes['sleeve_type'], SleeveType.unknown),
      warnings: (json['warnings'] as List? ?? const []).map((value) => '$value').toList(),
      modelVersion: '${model['version'] ?? 'unknown'}',
    );
  }
}

class TailorAssetReference {
  final String id;
  final String url;
  final String sha256;
  final int expiresInSeconds;

  const TailorAssetReference({required this.id, required this.url, required this.sha256, required this.expiresInSeconds});

  factory TailorAssetReference.fromJson(Object? value) {
    final map = _map(value);
    if (map['id'] is! String || map['url'] is! String || map['sha256'] is! String) {
      throw const FormatException('Malformed Tailor asset reference');
    }
    return TailorAssetReference(
      id: map['id'] as String,
      url: map['url'] as String,
      sha256: map['sha256'] as String,
      expiresInSeconds: (map['expires_in_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class TailorDigitization {
  final Map<String, SegmentationCandidate> views;
  final TailorAnalysis classification;
  final String status;
  final String primaryColor;
  final GarmentPattern pattern;
  final Set<Season> suggestedSeasons;
  final LayerRole layerRole;
  final TailorAssetReference? frontNormalized;
  final TailorAssetReference? frontMask;
  final TailorAssetReference? backNormalized;
  final TailorAssetReference? backMask;
  final bool segmentationReady;
  final bool tryOnReady;
  final List<String> warnings;
  final String processorVersion;
  final String? sourceImageHash;
  final String? normalizedImageHash;
  final String? maskHash;

  const TailorDigitization({this.views = const {}, required this.classification, required this.status, required this.primaryColor, required this.pattern, required this.suggestedSeasons, required this.layerRole, this.frontNormalized, this.frontMask, this.backNormalized, this.backMask, required this.segmentationReady, required this.tryOnReady, required this.warnings, required this.processorVersion, this.sourceImageHash, this.normalizedImageHash, this.maskHash});

  factory TailorDigitization.fromJson(Map<String, Object?> json) {
    final classification = _map(json['classification']);
    final attributes = _map(json['attributes']);
    final frontAssets = _map(_map(json['assets'])['front']);
    final backAssets = _map(_map(json['assets'])['back']);
    final readiness = _map(json['readiness']);
    final processor = _map(json['processor']);
    final frontIdentity = _map(_map(json['identity'])['front']);
    final colour = _map(attributes['primary_color']);
    final pattern = _map(attributes['pattern']);
    final adapted = <String, Object?>{
      'request_id': json['request_id'],
      'status': classification['abstained'] == true ? 'abstained' : 'predicted',
      'prediction': {
        'category': classification['category'],
        'confidence': classification['confidence'],
        'abstained': classification['abstained'],
        'top_predictions': classification['top_predictions'],
      },
      'derived_attributes': {'sleeve_type': classification['sleeve_type']},
      'model': {'version': classification['model_version']},
      'warnings': json['warnings'],
    };
    TailorAssetReference? asset(Map<String, Object?> map, String key) =>
        map[key] == null ? null : TailorAssetReference.fromJson(map[key]);
    return TailorDigitization(
      views: {for (final entry in _map(json['views']).entries)
        if (entry.value != null) entry.key: SegmentationCandidate.fromJson(_map(entry.value))},
      classification: TailorAnalysis.fromJson(adapted),
      status: '${json['status'] ?? 'partial'}',
      primaryColor: '${colour['primary_color'] ?? 'unknown'}',
      pattern: enumFromWire(GarmentPattern.values, pattern['value'], GarmentPattern.unknown),
      suggestedSeasons: (attributes['suggested_seasons'] as List? ?? const [])
          .map((value) => enumFromWire(Season.values, value, Season.spring)).toSet(),
      layerRole: enumFromWire(LayerRole.values, attributes['layer_role'], LayerRole.unknown),
      frontNormalized: asset(frontAssets, 'normalized'),
      frontMask: asset(frontAssets, 'mask'),
      backNormalized: asset(backAssets, 'normalized'),
      backMask: asset(backAssets, 'mask'),
      segmentationReady: readiness['segmentation_ready'] == true,
      tryOnReady: readiness['try_on_ready'] == true,
      warnings: (json['warnings'] as List? ?? const []).map((value) => '$value').toList(),
      processorVersion: '${processor['digitization_version'] ?? 'unknown'}',
      sourceImageHash: frontIdentity['source_image_sha256']?.toString(),
      normalizedImageHash: frontIdentity['normalized_image_sha256']?.toString(),
      maskHash: frontIdentity['mask_sha256']?.toString(),
    );
  }
}

Map<String, Object?> _map(Object? value) => value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};
