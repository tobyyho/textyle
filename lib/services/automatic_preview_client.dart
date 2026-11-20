import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'tailor_client.dart';
import 'tailor_models.dart';
import 'segmentation_candidate.dart';

class AutomaticPreviewResult {
  final TailorDigitization digitization;
  final Map<String, Object?> preview;
  AutomaticPreviewResult(this.digitization, this.preview);
  factory AutomaticPreviewResult.fromJson(Map<String, Object?> json) {
    if (json['status'] != 'preview_generated' || json['generated_preview'] is! Map) {
      throw const FormatException('Tailor did not return a generated preview.');
    }
    return AutomaticPreviewResult(TailorDigitization.fromJson(json),
        Map<String, Object?>.from(json['generated_preview'] as Map));
  }
}

class AutomaticPreviewClient {
  AutomaticPreviewClient(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();
  final TailorConfig config;
  final http.Client _http;
  static const timeout = Duration(seconds: 180);

  Future<AutomaticPreviewResult> create({required TailorImage front,
      required TailorImage back, required String garmentId, required String profile, String? confirmedCategory, String longSleeveStyle = 'auto', String maleTemplateStyle = 'auto', String finalTemplateStyle = 'auto', String templateCatalog = 'finished_v1'}) async {
    final request = http.MultipartRequest('POST', config.baseUrl.resolve('api/v1/clothing/automatic-preview'))
      ..headers['X-API-Key'] = config.apiKey
      ..fields.addAll({'garment_id': garmentId, 'body_profile': profile, 'source': 'closet_camera'})
      ..files.add(http.MultipartFile.fromBytes('front_image', front.bytes, filename: front.filename))
      ..files.add(http.MultipartFile.fromBytes('back_image', back.bytes, filename: back.filename));
    request.fields['long_sleeve_style'] = longSleeveStyle;
    request.fields['male_template_style'] = maleTemplateStyle;
    request.fields['template_catalog'] = maleTemplateStyle == 'auto' ? templateCatalog : 'legacy';
    request.fields['final_template_style'] = finalTemplateStyle;
    if (confirmedCategory != null) request.fields['confirmed_category'] = confirmedCategory;
    try {
      final response = await http.Response.fromStream(await _http.send(request).timeout(timeout)).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Tailor could not prepare this garment (${response.statusCode}).';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['detail'] is String) message = body['detail'] as String;
        } on Object { /* Keep the status-only message for non-JSON replies. */ }
        if (response.statusCode == 404) {
          message = 'The Tailor server needs the automatic-preview backend update.';
        }
        throw TailorException(TailorFailureKind.server, message, response.statusCode);
      }
      return AutomaticPreviewResult.fromJson(Map<String, Object?>.from(jsonDecode(response.body) as Map));
    } on TimeoutException {
      throw const TailorException(TailorFailureKind.timeout, 'Automatic processing timed out. Retry once after Tailor has finished starting.');
    }
  }

  Future<Uint8List> fetch(TailorAssetReference ref) async {
    final uri = config.baseUrl.resolve(ref.url.startsWith('/') ? ref.url.substring(1) : ref.url);
    if (uri.origin != config.baseUrl.origin) throw const FormatException('Unexpected asset origin.');
    final response = await _http.get(uri, headers: {'X-API-Key': config.apiKey}).timeout(timeout);
    if (response.statusCode != 200 || mediaHash(response.bodyBytes) != ref.sha256) {
      throw const FormatException('A generated asset is missing or changed. Retry processing.');
    }
    return response.bodyBytes;
  }
  void close() => _http.close();
}
