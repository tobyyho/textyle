enum BodyFamily { male, female }
enum ShapeVariant { slim, average, athletic, curvy }

enum CanonicalBodyProfileId {
  maleSlim('male_slim'),
  maleAverage('male_average'),
  maleAthletic('male_athletic'),
  femaleSlim('female_slim'),
  femaleAverage('female_average'),
  femaleCurvy('female_curvy');

  const CanonicalBodyProfileId(this.value);
  final String value;

  static CanonicalBodyProfileId parse(String value) => values.firstWhere(
        (profile) => profile.value == value,
        orElse: () => throw FormatException('Unknown canonical body profile: $value'),
      );
}

class MeasurementProfile {
  final double? heightCm;
  final double? shoulderWidthCm;
  final double? chestOrBustCm;
  final double? waistCm;
  final double? hipsCm;
  final double? inseamCm;
  final double? armLengthCm;

  const MeasurementProfile({this.heightCm, this.shoulderWidthCm, this.chestOrBustCm, this.waistCm, this.hipsCm, this.inseamCm, this.armLengthCm});

  Map<String, Object?> toJson() => {'heightCm': heightCm, 'shoulderWidthCm': shoulderWidthCm, 'chestOrBustCm': chestOrBustCm, 'waistCm': waistCm, 'hipsCm': hipsCm, 'inseamCm': inseamCm, 'armLengthCm': armLengthCm};

  factory MeasurementProfile.fromJson(Map<String, Object?> json) => MeasurementProfile(
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        shoulderWidthCm: (json['shoulderWidthCm'] as num?)?.toDouble(),
        chestOrBustCm: (json['chestOrBustCm'] as num?)?.toDouble(),
        waistCm: (json['waistCm'] as num?)?.toDouble(),
        hipsCm: (json['hipsCm'] as num?)?.toDouble(),
        inseamCm: (json['inseamCm'] as num?)?.toDouble(),
        armLengthCm: (json['armLengthCm'] as num?)?.toDouble(),
      );
}

class CanonicalBodyProfile {
  final CanonicalBodyProfileId id;
  final String displayName;
  final BodyFamily bodyFamily;
  final ShapeVariant shapeVariant;
  final String avatarAssetId;
  final String skeletonVersion;
  final String geometryVersion;
  final MeasurementProfile measurementProfile;
  final bool enabled;

  const CanonicalBodyProfile({required this.id, required this.displayName, required this.bodyFamily, required this.shapeVariant, required this.avatarAssetId, this.skeletonVersion = 'textyle_skeleton_v1', this.geometryVersion = '1', this.measurementProfile = const MeasurementProfile(), this.enabled = true});

  Map<String, Object?> toJson() => {'id': id.value, 'displayName': displayName, 'bodyFamily': bodyFamily.name, 'shapeVariant': shapeVariant.name, 'avatarAssetId': avatarAssetId, 'skeletonVersion': skeletonVersion, 'geometryVersion': geometryVersion, 'measurementProfile': measurementProfile.toJson(), 'enabled': enabled};

  factory CanonicalBodyProfile.fromJson(Map<String, Object?> json) => CanonicalBodyProfile(
        id: CanonicalBodyProfileId.parse('${json['id'] ?? ''}'),
        displayName: '${json['displayName'] ?? ''}',
        bodyFamily: BodyFamily.values.byName('${json['bodyFamily'] ?? ''}'),
        shapeVariant: ShapeVariant.values.byName('${json['shapeVariant'] ?? ''}'),
        avatarAssetId: '${json['avatarAssetId'] ?? ''}',
        skeletonVersion: '${json['skeletonVersion'] ?? ''}',
        geometryVersion: '${json['geometryVersion'] ?? ''}',
        measurementProfile: MeasurementProfile.fromJson(Map<String, Object?>.from(json['measurementProfile'] as Map? ?? const {})),
        enabled: json['enabled'] != false,
      );
}

const canonicalBodyProfiles = <CanonicalBodyProfile>[
  CanonicalBodyProfile(id: CanonicalBodyProfileId.maleSlim, displayName: 'Male Slim', bodyFamily: BodyFamily.male, shapeVariant: ShapeVariant.slim, avatarAssetId: 'textyle_body_male_slim_v1'),
  CanonicalBodyProfile(id: CanonicalBodyProfileId.maleAverage, displayName: 'Male Average', bodyFamily: BodyFamily.male, shapeVariant: ShapeVariant.average, avatarAssetId: 'textyle_body_male_average_v1'),
  CanonicalBodyProfile(id: CanonicalBodyProfileId.maleAthletic, displayName: 'Male Athletic', bodyFamily: BodyFamily.male, shapeVariant: ShapeVariant.athletic, avatarAssetId: 'textyle_body_male_athletic_v1'),
  CanonicalBodyProfile(id: CanonicalBodyProfileId.femaleSlim, displayName: 'Female Slim', bodyFamily: BodyFamily.female, shapeVariant: ShapeVariant.slim, avatarAssetId: 'textyle_body_female_slim_v1'),
  CanonicalBodyProfile(id: CanonicalBodyProfileId.femaleAverage, displayName: 'Female Average', bodyFamily: BodyFamily.female, shapeVariant: ShapeVariant.average, avatarAssetId: 'textyle_body_female_average_v1'),
  CanonicalBodyProfile(id: CanonicalBodyProfileId.femaleCurvy, displayName: 'Female Curvy', bodyFamily: BodyFamily.female, shapeVariant: ShapeVariant.curvy, avatarAssetId: 'textyle_body_female_curvy_v1'),
];

CanonicalBodyProfile bodyProfile(CanonicalBodyProfileId id) => canonicalBodyProfiles.singleWhere((profile) => profile.id == id);
