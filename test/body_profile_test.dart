import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/body_profile.dart';

void main() {
  test('exactly six unique canonical body profiles round-trip', () {
    expect(canonicalBodyProfiles.map((profile) => profile.id.value).toList(), [
      'male_slim',
      'male_average',
      'male_athletic',
      'female_slim',
      'female_average',
      'female_curvy',
    ]);
    expect(canonicalBodyProfiles.map((profile) => profile.id).toSet(), hasLength(6));
    for (final profile in canonicalBodyProfiles) {
      expect(CanonicalBodyProfile.fromJson(profile.toJson()).toJson(), profile.toJson());
      expect(profile.measurementProfile.toJson().values, everyElement(isNull));
    }
  });

  test('invalid profile IDs fail closed', () {
    expect(() => CanonicalBodyProfileId.parse('invented'), throwsFormatException);
  });
}
