import '../models/clothing_item.dart';

class AutomaticGarmentTemplate {
  const AutomaticGarmentTemplate(this.version, this.profile, this.category, this.sha256, this.method);
  final String version, profile, sha256, method;
  final GarmentCategory category;
  bool get isLegacyTshirt => version == 'male_tshirt_auto_projection_v1';
}

const automaticGarmentTemplates = <AutomaticGarmentTemplate>[
  AutomaticGarmentTemplate('male_tshirt_auto_projection_v1', 'male_average', GarmentCategory.shortSleeveTop,
    '520b39f5e4ba332a65726be488c6417df34f4bf23be1bcefb1c21c0ea8d2ad0e', 'automatic_mask_torso_v1'),
  AutomaticGarmentTemplate('male_long_sleeve_photo_v1', 'male_average', GarmentCategory.longSleeveTop,
    '1ad88ff83cf964c6a714c9172bb9ed860e8526e5e810e31b09a544093affedac', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('female_long_sleeve_photo_v1', 'female_average', GarmentCategory.longSleeveTop,
    'de1e2cde165eef7f2dc3674b9175ec8c3f336fdc86aeda6eba10c6934f8cf69e', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_trousers_photo_v1', 'male_average', GarmentCategory.trousers,
    'e23105bb337f9a9567259e5b622a0357b685f95bcf5f394bddf00ea5754d05fa', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('female_trousers_photo_v1', 'female_average', GarmentCategory.trousers,
    '483274413143e14f2a676adb2fc8eaef55d3f104bc5c709bad15df647359cc0e', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('female_tshirt_auto_projection_v1', 'female_average', GarmentCategory.shortSleeveTop,
    '4dd12f793edefcb3188f566d6f8084e9e9c89bd51c7819dd933bf01640906143', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_user_tshirt_v1', 'male_average', GarmentCategory.shortSleeveTop,
    '520b39f5e4ba332a65726be488c6417df34f4bf23be1bcefb1c21c0ea8d2ad0e', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_user_long_tee_v1', 'male_average', GarmentCategory.longSleeveTop,
    'cad08f9a33d937f43360baf9e130d11d7e21415424c3384836dc6ab2122e7ca0', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_user_sweater_v1', 'male_average', GarmentCategory.longSleeveTop,
    '2888e434751b96b2a7ccb8c0b7a8a3eaa5b961d26351044473790b5755d75122', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_user_jeans_v1', 'male_average', GarmentCategory.trousers,
    'e23105bb337f9a9567259e5b622a0357b685f95bcf5f394bddf00ea5754d05fa', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_user_black_pants_v1', 'male_average', GarmentCategory.trousers,
    '12baee3ef12af409797e6454218bf72bd72ffdcbd2380c888242c72d9b6b736d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_user_ankle_sweats_v1', 'male_average', GarmentCategory.trousers,
    'fc300bc83fc6c730e7cc891e0b631b84835bd666f4098289dc77e5bd9dec690d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('male_user_shorts_v1', 'male_average', GarmentCategory.shorts,
    'f02703194cb75bcdfa868b1cae170c26c118ec0c852cee7ffb61afaee8b8eee5', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_tshirt_20261115_v1', 'male_average', GarmentCategory.shortSleeveTop,
    'a67b6b7013edb29133c96a53aa323c1a725838892cd66aa77e1c7b3e8512c239', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_long_tee_20261115_v1', 'male_average', GarmentCategory.longSleeveTop,
    'f6b2601cf2f064f231f518467ab9fe94c8ab0384c0ab3ed6d35ee4ce95463427', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_sweater_20261115_v1', 'male_average', GarmentCategory.longSleeveTop,
    'e46b74591bfba6ca441defca8c95f7488bfe03991f964911d65e17dedfea3e63', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_zip_hoodie_20261115_v1', 'male_average', GarmentCategory.outerwear,
    'f6de119c680c74595219d88e3c168e965916301a587fe5255118594db1e8259a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_ankle_sweats_20261115_v1', 'male_average', GarmentCategory.trousers,
    '33d126ea66ef230ccf6f1a53fca504a4992eaa0862a06be1f6ec69d2a9a82f4f', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_drawstring_sweats_20261115_v1', 'male_average', GarmentCategory.trousers,
    'bcfd50b17749595db7ab1c40a85663340a8226c815b9c75df246068a5d8d5da3', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_shorts_20261115_v1', 'male_average', GarmentCategory.shorts,
    'e22d1d5746549480d4e3f06b627011ad2d303659bf5e2d24607d7ab95cea545a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_tshirt_20261115_v1', 'female_average', GarmentCategory.shortSleeveTop,
    '7d32c10c7939d634ef8d5c3c3b9824f523b199a4d58d9860f91142443c5c24ab', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_sweater_20261115_v1', 'female_average', GarmentCategory.longSleeveTop,
    '4ffceee6941b8f138792157001396cca652c9e336f2ef51c202c5d9008826f9c', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_skinny_jeans_20261115_v1', 'female_average', GarmentCategory.trousers,
    '483274413143e14f2a676adb2fc8eaef55d3f104bc5c709bad15df647359cc0e', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_capris_20261115_v1', 'female_average', GarmentCategory.trousers,
    '0a482e161b4c88a5c5d53ad3970bb069804a8f687b71d40ff11b0d29ee46db5a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_ankle_sweats_20261115_v1', 'female_average', GarmentCategory.trousers,
    'b372e77f3273730d7c35812c987aa558088ee1e5c0f6307e46754b23126600e7', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_sweats_20261115_v1', 'female_average', GarmentCategory.trousers,
    '79266292cdcbe498f68ddfa46d61459d4feb927bd1049f157fbace2ad7eea724', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_pleated_skirt_20261115_v1', 'female_average', GarmentCategory.skirt,
    '6c04ca5baa9fde1b763b39ef6a30a25465bf11d0c862a22b6f2dd434f3851069', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_tshirt_20261115_v3', 'male_average', GarmentCategory.shortSleeveTop,
    'a67b6b7013edb29133c96a53aa323c1a725838892cd66aa77e1c7b3e8512c239', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_sweater_20261115_v3', 'male_average', GarmentCategory.longSleeveTop,
    'c4cde24da1d127b474136397a6ce0536b91159c8963616181f45d9f46bfdab1d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_long_tee_20261115_v3', 'male_average', GarmentCategory.longSleeveTop,
    'f6b2601cf2f064f231f518467ab9fe94c8ab0384c0ab3ed6d35ee4ce95463427', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_zip_hoodie_20261115_v3', 'male_average', GarmentCategory.outerwear,
    'f6de119c680c74595219d88e3c168e965916301a587fe5255118594db1e8259a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_ankle_sweats_20261115_v3', 'male_average', GarmentCategory.trousers,
    '33d126ea66ef230ccf6f1a53fca504a4992eaa0862a06be1f6ec69d2a9a82f4f', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_drawstring_sweats_20261115_v3', 'male_average', GarmentCategory.trousers,
    'bcfd50b17749595db7ab1c40a85663340a8226c815b9c75df246068a5d8d5da3', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_jeans_20261115_v3', 'male_average', GarmentCategory.trousers,
    'e23105bb337f9a9567259e5b622a0357b685f95bcf5f394bddf00ea5754d05fa', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_black_pants_20261115_v3', 'male_average', GarmentCategory.trousers,
    '12baee3ef12af409797e6454218bf72bd72ffdcbd2380c888242c72d9b6b736d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_tshirt_20261115_v3', 'female_average', GarmentCategory.shortSleeveTop,
    '7d32c10c7939d634ef8d5c3c3b9824f523b199a4d58d9860f91142443c5c24ab', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_sweater_20261115_v3', 'female_average', GarmentCategory.longSleeveTop,
    '5ff64a05d01f391a5c010017616a96982cb8dafad45098c26e7cf1db9fa72f66', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_long_tee_20261115_v3', 'female_average', GarmentCategory.longSleeveTop,
    '76b2c79118f89ab7b6d4078729a52f93105d9edcbb3ac20a06937480c5475566', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_hoodie_20261115_v3', 'female_average', GarmentCategory.outerwear,
    '546f4a39161e0fdb1ba9efb88fd19b4fcdc63d65955b7b7399d704abd78eacea', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_button_up_20261115_v3', 'female_average', GarmentCategory.longSleeveTop,
    'a0b779222883224751e9aba29a1dbfc53d43b7514015be49cb962976c25b4b96', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_pleated_skirt_20261115_v3', 'female_average', GarmentCategory.skirt,
    '6c04ca5baa9fde1b763b39ef6a30a25465bf11d0c862a22b6f2dd434f3851069', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_capris_20261115_v3', 'female_average', GarmentCategory.trousers,
    '0a482e161b4c88a5c5d53ad3970bb069804a8f687b71d40ff11b0d29ee46db5a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_ankle_sweats_20261115_v3', 'female_average', GarmentCategory.trousers,
    'cc1cf56e8139a2923566e5b3db760b4b8da948b23e05dbfa99c6d8cbca6c50ad', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_skinny_jeans_20261115_v3', 'female_average', GarmentCategory.trousers,
    '483274413143e14f2a676adb2fc8eaef55d3f104bc5c709bad15df647359cc0e', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_long_tee_20261115_v2', 'male_average', GarmentCategory.longSleeveTop,
    'f6b2601cf2f064f231f518467ab9fe94c8ab0384c0ab3ed6d35ee4ce95463427', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_sweater_20261115_v2', 'male_average', GarmentCategory.longSleeveTop,
    'c4cde24da1d127b474136397a6ce0536b91159c8963616181f45d9f46bfdab1d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_zip_hoodie_20261115_v2', 'male_average', GarmentCategory.outerwear,
    'f6de119c680c74595219d88e3c168e965916301a587fe5255118594db1e8259a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_ankle_sweats_20261115_v2', 'male_average', GarmentCategory.trousers,
    '33d126ea66ef230ccf6f1a53fca504a4992eaa0862a06be1f6ec69d2a9a82f4f', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_drawstring_sweats_20261115_v2', 'male_average', GarmentCategory.trousers,
    'bcfd50b17749595db7ab1c40a85663340a8226c815b9c75df246068a5d8d5da3', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_shorts_20261115_v2', 'male_average', GarmentCategory.shorts,
    'e22d1d5746549480d4e3f06b627011ad2d303659bf5e2d24607d7ab95cea545a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_long_tee_20261115_v2', 'female_average', GarmentCategory.longSleeveTop,
    '76b2c79118f89ab7b6d4078729a52f93105d9edcbb3ac20a06937480c5475566', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_sweater_20261115_v2', 'female_average', GarmentCategory.longSleeveTop,
    '5ff64a05d01f391a5c010017616a96982cb8dafad45098c26e7cf1db9fa72f66', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_button_up_20261115_v2', 'female_average', GarmentCategory.longSleeveTop,
    'a0b779222883224751e9aba29a1dbfc53d43b7514015be49cb962976c25b4b96', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_hoodie_20261115_v2', 'female_average', GarmentCategory.outerwear,
    '546f4a39161e0fdb1ba9efb88fd19b4fcdc63d65955b7b7399d704abd78eacea', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_ankle_sweats_20261115_v2', 'female_average', GarmentCategory.trousers,
    'cc1cf56e8139a2923566e5b3db760b4b8da948b23e05dbfa99c6d8cbca6c50ad', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_skinny_jeans_20261115_v2', 'female_average', GarmentCategory.trousers,
    '483274413143e14f2a676adb2fc8eaef55d3f104bc5c709bad15df647359cc0e', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_capris_20261115_v2', 'female_average', GarmentCategory.trousers,
    '0a482e161b4c88a5c5d53ad3970bb069804a8f687b71d40ff11b0d29ee46db5a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_pleated_skirt_20261115_v2', 'female_average', GarmentCategory.skirt,
    '6c04ca5baa9fde1b763b39ef6a30a25465bf11d0c862a22b6f2dd434f3851069', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_baggy_sweats_20261115_v4', 'male_average', GarmentCategory.trousers,
    '12baee3ef12af409797e6454218bf72bd72ffdcbd2380c888242c72d9b6b736d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_shorts_20261115_v4', 'male_average', GarmentCategory.shorts,
    'e22d1d5746549480d4e3f06b627011ad2d303659bf5e2d24607d7ab95cea545a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_hoodie_20261115_v4', 'female_average', GarmentCategory.outerwear,
    'ae7e3cd712437bab523987371c2ab183828b5f86a74fae81d61579a9b6844dc3', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_tshirt_20261115_v5', 'male_average', GarmentCategory.shortSleeveTop,
    '2dfb82d768697b9330169c7f056485bafa6e33524b2ec505b53208cd04d200c5', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_sweater_20261115_v5', 'male_average', GarmentCategory.longSleeveTop,
    'c4cde24da1d127b474136397a6ce0536b91159c8963616181f45d9f46bfdab1d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_long_tee_20261115_v5', 'male_average', GarmentCategory.longSleeveTop,
    'f6b2601cf2f064f231f518467ab9fe94c8ab0384c0ab3ed6d35ee4ce95463427', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_hoodie_20261115_v5', 'male_average', GarmentCategory.outerwear,
    '5c7f0d5f54fe0ff0636790d0f0c9fed211d4a3de39f9d56a771cc665113d52d6', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_zip_hoodie_20261115_v5', 'male_average', GarmentCategory.outerwear,
    'f6de119c680c74595219d88e3c168e965916301a587fe5255118594db1e8259a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_ankle_sweats_20261115_v5', 'male_average', GarmentCategory.trousers,
    '33d126ea66ef230ccf6f1a53fca504a4992eaa0862a06be1f6ec69d2a9a82f4f', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_drawstring_sweats_20261115_v5', 'male_average', GarmentCategory.trousers,
    'bcfd50b17749595db7ab1c40a85663340a8226c815b9c75df246068a5d8d5da3', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_baggy_sweats_20261115_v5', 'male_average', GarmentCategory.trousers,
    '12baee3ef12af409797e6454218bf72bd72ffdcbd2380c888242c72d9b6b736d', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_male_shorts_20261115_v5', 'male_average', GarmentCategory.shorts,
    'e22d1d5746549480d4e3f06b627011ad2d303659bf5e2d24607d7ab95cea545a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_tshirt_20261115_v5', 'female_average', GarmentCategory.shortSleeveTop,
    '7d32c10c7939d634ef8d5c3c3b9824f523b199a4d58d9860f91142443c5c24ab', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_sweater_20261115_v5', 'female_average', GarmentCategory.longSleeveTop,
    '5ff64a05d01f391a5c010017616a96982cb8dafad45098c26e7cf1db9fa72f66', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_long_tee_20261115_v5', 'female_average', GarmentCategory.longSleeveTop,
    '76b2c79118f89ab7b6d4078729a52f93105d9edcbb3ac20a06937480c5475566', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_hoodie_20261115_v5', 'female_average', GarmentCategory.outerwear,
    '546f4a39161e0fdb1ba9efb88fd19b4fcdc63d65955b7b7399d704abd78eacea', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_zip_hoodie_20261115_v5', 'female_average', GarmentCategory.outerwear,
    '5cfd43d75ca9042d3ba1600029b317163790208b76ca35bee15369cb10da858c', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_button_up_20261115_v5', 'female_average', GarmentCategory.longSleeveTop,
    'a0b779222883224751e9aba29a1dbfc53d43b7514015be49cb962976c25b4b96', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_pleated_skirt_20261115_v5', 'female_average', GarmentCategory.skirt,
    '6c04ca5baa9fde1b763b39ef6a30a25465bf11d0c862a22b6f2dd434f3851069', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_capris_20261115_v5', 'female_average', GarmentCategory.trousers,
    '0a482e161b4c88a5c5d53ad3970bb069804a8f687b71d40ff11b0d29ee46db5a', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_ankle_sweats_20261115_v5', 'female_average', GarmentCategory.trousers,
    'cc1cf56e8139a2923566e5b3db760b4b8da948b23e05dbfa99c6d8cbca6c50ad', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_skinny_jeans_20261115_v5', 'female_average', GarmentCategory.trousers,
    '483274413143e14f2a676adb2fc8eaef55d3f104bc5c709bad15df647359cc0e', 'automatic_photo_parts_v1'),
  AutomaticGarmentTemplate('finished_female_sweats_20261115_v5', 'female_average', GarmentCategory.trousers,
    '79266292cdcbe498f68ddfa46d61459d4feb927bd1049f157fbace2ad7eea724', 'automatic_photo_parts_v1'),
];
AutomaticGarmentTemplate? automaticTemplateFor(String profile, GarmentCategory category) {
  for (final template in automaticGarmentTemplates) {
    if (template.profile == profile && template.category == category) return template;
  }
  return null;
}
AutomaticGarmentTemplate? automaticTemplateByVersion(String? version) {
  for (final template in automaticGarmentTemplates) {
    if (template.version == version) return template;
  }
  return null;
}
bool isPartPhotoTemplateVersion(String? version) {
  final template = automaticTemplateByVersion(version);
  return template != null && !template.isLegacyTshirt;
}
bool isAutomaticPhotoTemplateVersion(String? version) => automaticTemplateByVersion(version) != null;
bool automaticProfileSupported(String profile) =>
    automaticGarmentTemplates.any((template) => template.profile == profile);

const maleGarmentStyles = <String, String>{
  'tshirt': 'T-shirt',
  'long_tee': 'Long-sleeve T-shirt',
  'sweater': 'Sweater',
  'jeans': 'Jeans',
  'black_pants': 'Black pants',
  'ankle_sweats': 'Cuffed sweatpants',
  'shorts': 'Shorts',
};

AutomaticGarmentTemplate? maleTemplateByStyle(String style) => automaticTemplateByVersion('male_user_${style}_v1');

bool isUserMaleTemplateVersion(String? version) => version?.startsWith('male_user_') == true;

class FinishedGarmentStyle {
  const FinishedGarmentStyle(this.key, this.label, this.profile, this.category, this.version, this.assetPath);
  final String key, label, profile, version, assetPath;
  final GarmentCategory category;
}
const legacyFinishedGarmentStyles = <FinishedGarmentStyle>[
  FinishedGarmentStyle('tshirt', 'T-shirt', 'male_average', GarmentCategory.shortSleeveTop, 'finished_male_tshirt_20261115_v1', 'assets/clothing/male/tops/tshirt.glb'),
  FinishedGarmentStyle('long_tee', 'Long-sleeve T-shirt', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_long_tee_20261115_v1', 'assets/clothing/male/tops/long_tee.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_sweater_20261115_v1', 'assets/clothing/male/tops/sweater.glb'),
  FinishedGarmentStyle('zip_hoodie', 'Zip-up hoodie', 'male_average', GarmentCategory.outerwear, 'finished_male_zip_hoodie_20261115_v1', 'assets/clothing/male/tops/zip_hoodie.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Ankle sweatpants', 'male_average', GarmentCategory.trousers, 'finished_male_ankle_sweats_20261115_v1', 'assets/clothing/male/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('drawstring_sweats', 'Drawstring sweatpants', 'male_average', GarmentCategory.trousers, 'finished_male_drawstring_sweats_20261115_v1', 'assets/clothing/male/bottoms/drawstring_sweats.glb'),
  FinishedGarmentStyle('shorts', 'Shorts', 'male_average', GarmentCategory.shorts, 'finished_male_shorts_20261115_v1', 'assets/clothing/male/bottoms/shorts.glb'),
  FinishedGarmentStyle('tshirt', 'T-shirt', 'female_average', GarmentCategory.shortSleeveTop, 'finished_female_tshirt_20261115_v1', 'assets/clothing/female/tops/tshirt.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_sweater_20261115_v1', 'assets/clothing/female/tops/sweater.glb'),
  FinishedGarmentStyle('skinny_jeans', 'Skinny jeans', 'female_average', GarmentCategory.trousers, 'finished_female_skinny_jeans_20261115_v1', 'assets/clothing/female/bottoms/skinny_jeans.glb'),
  FinishedGarmentStyle('capris', 'Capris', 'female_average', GarmentCategory.trousers, 'finished_female_capris_20261115_v1', 'assets/clothing/female/bottoms/capris.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Ankle sweatpants', 'female_average', GarmentCategory.trousers, 'finished_female_ankle_sweats_20261115_v1', 'assets/clothing/female/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('sweats', 'Sweatpants', 'female_average', GarmentCategory.trousers, 'finished_female_sweats_20261115_v1', 'assets/clothing/female/bottoms/sweats.glb'),
  FinishedGarmentStyle('pleated_skirt', 'Pleated skirt', 'female_average', GarmentCategory.skirt, 'finished_female_pleated_skirt_20261115_v1', 'assets/clothing/female/bottoms/pleated_skirt.glb'),

  FinishedGarmentStyle('tshirt', 'T-shirt', 'male_average', GarmentCategory.shortSleeveTop, 'finished_male_tshirt_20261115_v3', 'assets/clothing/male/tops/tshirt.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_sweater_20261115_v3', 'assets/clothing/male/tops/sweater.glb'),
  FinishedGarmentStyle('long_tee', 'Long sleeve', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_long_tee_20261115_v3', 'assets/clothing/male/tops/long_tee.glb'),
  FinishedGarmentStyle('zip_hoodie', 'Hoodie', 'male_average', GarmentCategory.outerwear, 'finished_male_zip_hoodie_20261115_v3', 'assets/clothing/male/tops/zip_hoodie.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Sweats', 'male_average', GarmentCategory.trousers, 'finished_male_ankle_sweats_20261115_v3', 'assets/clothing/male/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('drawstring_sweats', 'Drawstring sweatpants', 'male_average', GarmentCategory.trousers, 'finished_male_drawstring_sweats_20261115_v3', 'assets/clothing/male/bottoms/drawstring_sweats.glb'),
  FinishedGarmentStyle('jeans', 'Jeans', 'male_average', GarmentCategory.trousers, 'finished_male_jeans_20261115_v3', 'assets/clothing/male/bottoms/jeans.glb'),
  FinishedGarmentStyle('black_pants', 'Black pants', 'male_average', GarmentCategory.trousers, 'finished_male_black_pants_20261115_v3', 'assets/clothing/male/bottoms/black_pants.glb'),
  FinishedGarmentStyle('tshirt', 'T-shirt', 'female_average', GarmentCategory.shortSleeveTop, 'finished_female_tshirt_20261115_v3', 'assets/clothing/female/tops/tshirt.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_sweater_20261115_v3', 'assets/clothing/female/tops/sweater.glb'),
  FinishedGarmentStyle('long_tee', 'Long sleeve', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_long_tee_20261115_v3', 'assets/clothing/female/tops/long_tee.glb'),
  FinishedGarmentStyle('hoodie', 'Hoodie', 'female_average', GarmentCategory.outerwear, 'finished_female_hoodie_20261115_v3', 'assets/clothing/female/tops/hoodie.glb'),
  FinishedGarmentStyle('button_up', 'Button-up shirt', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_button_up_20261115_v3', 'assets/clothing/female/tops/button_up.glb'),
  FinishedGarmentStyle('pleated_skirt', 'Skirt', 'female_average', GarmentCategory.skirt, 'finished_female_pleated_skirt_20261115_v3', 'assets/clothing/female/bottoms/pleated_skirt.glb'),
  FinishedGarmentStyle('capris', 'Capris', 'female_average', GarmentCategory.trousers, 'finished_female_capris_20261115_v3', 'assets/clothing/female/bottoms/capris.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Ankle sweatpants', 'female_average', GarmentCategory.trousers, 'finished_female_ankle_sweats_20261115_v3', 'assets/clothing/female/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('skinny_jeans', 'Skinny jeans', 'female_average', GarmentCategory.trousers, 'finished_female_skinny_jeans_20261115_v3', 'assets/clothing/female/bottoms/skinny_jeans.glb'),

  FinishedGarmentStyle('tshirt', 'T-shirt', 'male_average', GarmentCategory.shortSleeveTop, 'finished_male_tshirt_20261115_v3', 'assets/clothing/male/tops/tshirt.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_sweater_20261115_v3', 'assets/clothing/male/tops/sweater.glb'),
  FinishedGarmentStyle('long_tee', 'Long sleeve', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_long_tee_20261115_v3', 'assets/clothing/male/tops/long_tee.glb'),
  FinishedGarmentStyle('zip_hoodie', 'Hoodie', 'male_average', GarmentCategory.outerwear, 'finished_male_zip_hoodie_20261115_v3', 'assets/clothing/male/tops/zip_hoodie.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Sweats', 'male_average', GarmentCategory.trousers, 'finished_male_ankle_sweats_20261115_v3', 'assets/clothing/male/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('drawstring_sweats', 'Drawstring sweatpants', 'male_average', GarmentCategory.trousers, 'finished_male_drawstring_sweats_20261115_v3', 'assets/clothing/male/bottoms/drawstring_sweats.glb'),
  FinishedGarmentStyle('baggy_sweats', 'Baggy sweats', 'male_average', GarmentCategory.trousers, 'finished_male_baggy_sweats_20261115_v4', 'assets/clothing/male/bottoms/baggy_sweats.glb'),
  FinishedGarmentStyle('shorts', 'Shorts', 'male_average', GarmentCategory.shorts, 'finished_male_shorts_20261115_v4', 'assets/clothing/male/bottoms/shorts.glb'),
  FinishedGarmentStyle('tshirt', 'T-shirt', 'female_average', GarmentCategory.shortSleeveTop, 'finished_female_tshirt_20261115_v3', 'assets/clothing/female/tops/tshirt.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_sweater_20261115_v3', 'assets/clothing/female/tops/sweater.glb'),
  FinishedGarmentStyle('long_tee', 'Long sleeve', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_long_tee_20261115_v3', 'assets/clothing/female/tops/long_tee.glb'),
  FinishedGarmentStyle('hoodie', 'Hoodie', 'female_average', GarmentCategory.outerwear, 'finished_female_hoodie_20261115_v4', 'assets/clothing/female/tops/hoodie.glb'),
  FinishedGarmentStyle('button_up', 'Button-up shirt', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_button_up_20261115_v3', 'assets/clothing/female/tops/button_up.glb'),
  FinishedGarmentStyle('pleated_skirt', 'Skirt', 'female_average', GarmentCategory.skirt, 'finished_female_pleated_skirt_20261115_v3', 'assets/clothing/female/bottoms/pleated_skirt.glb'),
  FinishedGarmentStyle('capris', 'Capris', 'female_average', GarmentCategory.trousers, 'finished_female_capris_20261115_v3', 'assets/clothing/female/bottoms/capris.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Ankle sweatpants', 'female_average', GarmentCategory.trousers, 'finished_female_ankle_sweats_20261115_v3', 'assets/clothing/female/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('skinny_jeans', 'Skinny jeans', 'female_average', GarmentCategory.trousers, 'finished_female_skinny_jeans_20261115_v3', 'assets/clothing/female/bottoms/skinny_jeans.glb'),

];
const previousFinishedGarmentStyles = <FinishedGarmentStyle>[
  FinishedGarmentStyle('long_tee', 'Long-sleeve T-shirt', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_long_tee_20261115_v2', 'assets/clothing/male/tops/long_tee.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_sweater_20261115_v2', 'assets/clothing/male/tops/sweater.glb'),
  FinishedGarmentStyle('zip_hoodie', 'Zip-up hoodie', 'male_average', GarmentCategory.outerwear, 'finished_male_zip_hoodie_20261115_v2', 'assets/clothing/male/tops/zip_hoodie.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Ankle sweatpants', 'male_average', GarmentCategory.trousers, 'finished_male_ankle_sweats_20261115_v2', 'assets/clothing/male/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('drawstring_sweats', 'Drawstring sweatpants', 'male_average', GarmentCategory.trousers, 'finished_male_drawstring_sweats_20261115_v2', 'assets/clothing/male/bottoms/drawstring_sweats.glb'),
  FinishedGarmentStyle('shorts', 'Shorts', 'male_average', GarmentCategory.shorts, 'finished_male_shorts_20261115_v2', 'assets/clothing/male/bottoms/shorts.glb'),
  FinishedGarmentStyle('long_tee', 'Long-sleeve T-shirt', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_long_tee_20261115_v2', 'assets/clothing/female/tops/long_tee.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_sweater_20261115_v2', 'assets/clothing/female/tops/sweater.glb'),
  FinishedGarmentStyle('button_up', 'Button-up shirt', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_button_up_20261115_v2', 'assets/clothing/female/tops/button_up.glb'),
  FinishedGarmentStyle('hoodie', 'Hoodie', 'female_average', GarmentCategory.outerwear, 'finished_female_hoodie_20261115_v2', 'assets/clothing/female/tops/hoodie.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Ankle sweatpants', 'female_average', GarmentCategory.trousers, 'finished_female_ankle_sweats_20261115_v2', 'assets/clothing/female/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('skinny_jeans', 'Skinny jeans', 'female_average', GarmentCategory.trousers, 'finished_female_skinny_jeans_20261115_v2', 'assets/clothing/female/bottoms/skinny_jeans.glb'),
  FinishedGarmentStyle('capris', 'Capris', 'female_average', GarmentCategory.trousers, 'finished_female_capris_20261115_v2', 'assets/clothing/female/bottoms/capris.glb'),
  FinishedGarmentStyle('pleated_skirt', 'Pleated skirt', 'female_average', GarmentCategory.skirt, 'finished_female_pleated_skirt_20261115_v2', 'assets/clothing/female/bottoms/pleated_skirt.glb'),
];
const finishedGarmentStyles = <FinishedGarmentStyle>[
  FinishedGarmentStyle('tshirt', 'T-shirt', 'male_average', GarmentCategory.shortSleeveTop, 'finished_male_tshirt_20261115_v5', 'assets/clothing/male/tops/tshirt.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_sweater_20261115_v5', 'assets/clothing/male/tops/sweater.glb'),
  FinishedGarmentStyle('long_tee', 'Long sleeve', 'male_average', GarmentCategory.longSleeveTop, 'finished_male_long_tee_20261115_v5', 'assets/clothing/male/tops/long_tee.glb'),
  FinishedGarmentStyle('hoodie', 'Hoodie', 'male_average', GarmentCategory.outerwear, 'finished_male_hoodie_20261115_v5', 'assets/clothing/male/tops/hoodie.glb'),
  FinishedGarmentStyle('zip_hoodie', 'Zip-up hoodie', 'male_average', GarmentCategory.outerwear, 'finished_male_zip_hoodie_20261115_v5', 'assets/clothing/male/tops/zip_hoodie.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Sweats', 'male_average', GarmentCategory.trousers, 'finished_male_ankle_sweats_20261115_v5', 'assets/clothing/male/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('drawstring_sweats', 'Drawstring sweats', 'male_average', GarmentCategory.trousers, 'finished_male_drawstring_sweats_20261115_v5', 'assets/clothing/male/bottoms/drawstring_sweats.glb'),
  FinishedGarmentStyle('baggy_sweats', 'Baggy sweats', 'male_average', GarmentCategory.trousers, 'finished_male_baggy_sweats_20261115_v5', 'assets/clothing/male/bottoms/baggy_sweats.glb'),
  FinishedGarmentStyle('shorts', 'Shorts', 'male_average', GarmentCategory.shorts, 'finished_male_shorts_20261115_v5', 'assets/clothing/male/bottoms/shorts.glb'),
  FinishedGarmentStyle('tshirt', 'T-shirt', 'female_average', GarmentCategory.shortSleeveTop, 'finished_female_tshirt_20261115_v5', 'assets/clothing/female/tops/tshirt.glb'),
  FinishedGarmentStyle('sweater', 'Sweater', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_sweater_20261115_v5', 'assets/clothing/female/tops/sweater.glb'),
  FinishedGarmentStyle('long_tee', 'Long sleeve', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_long_tee_20261115_v5', 'assets/clothing/female/tops/long_tee.glb'),
  FinishedGarmentStyle('hoodie', 'Hoodie', 'female_average', GarmentCategory.outerwear, 'finished_female_hoodie_20261115_v5', 'assets/clothing/female/tops/hoodie.glb'),
  FinishedGarmentStyle('zip_hoodie', 'Zip-up hoodie', 'female_average', GarmentCategory.outerwear, 'finished_female_zip_hoodie_20261115_v5', 'assets/clothing/female/tops/zip_hoodie.glb'),
  FinishedGarmentStyle('button_up', 'Button-up shirt', 'female_average', GarmentCategory.longSleeveTop, 'finished_female_button_up_20261115_v5', 'assets/clothing/female/tops/button_up.glb'),
  FinishedGarmentStyle('pleated_skirt', 'Skirt', 'female_average', GarmentCategory.skirt, 'finished_female_pleated_skirt_20261115_v5', 'assets/clothing/female/bottoms/pleated_skirt.glb'),
  FinishedGarmentStyle('capris', 'Capris', 'female_average', GarmentCategory.trousers, 'finished_female_capris_20261115_v5', 'assets/clothing/female/bottoms/capris.glb'),
  FinishedGarmentStyle('ankle_sweats', 'Ankle sweats', 'female_average', GarmentCategory.trousers, 'finished_female_ankle_sweats_20261115_v5', 'assets/clothing/female/bottoms/ankle_sweats.glb'),
  FinishedGarmentStyle('skinny_jeans', 'Skinny jeans', 'female_average', GarmentCategory.trousers, 'finished_female_skinny_jeans_20261115_v5', 'assets/clothing/female/bottoms/skinny_jeans.glb'),
  FinishedGarmentStyle('sweats', 'Sweats', 'female_average', GarmentCategory.trousers, 'finished_female_sweats_20261115_v5', 'assets/clothing/female/bottoms/sweats.glb'),
];
List<FinishedGarmentStyle> finishedStylesFor(String profile) =>
    finishedGarmentStyles.where((style) => style.profile == profile).toList(growable: false);
FinishedGarmentStyle? finishedStyleByVersion(String? version) {
  for (final style in [...finishedGarmentStyles, ...previousFinishedGarmentStyles, ...legacyFinishedGarmentStyles]) {
    if (style.version == version) return style;
  }
  return null;
}
AutomaticGarmentTemplate? finishedTemplateByStyle(String profile, String key) {
  for (final style in finishedGarmentStyles) {
    if (style.profile == profile && style.key == key) return automaticTemplateByVersion(style.version);
  }
  return null;
}
bool isFinishedTemplateVersion(String? version) => finishedStyleByVersion(version) != null;
