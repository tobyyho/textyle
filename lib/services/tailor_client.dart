import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'tailor_models.dart';
import 'segmentation_candidate.dart';

enum TailorFailureKind { unavailable, timeout, unauthorized, tooLarge, unsupportedFormat, invalidImage, rateLimited, notReady, malformedResponse, server, network }

class TailorException implements Exception {
  final TailorFailureKind kind;
  final String message;
  final int? statusCode;
  const TailorException(this.kind, this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class TailorImage {
  final Uint8List bytes;
  final String filename;
  const TailorImage(this.bytes, this.filename);
}

abstract interface class TailorClientBase {
  Future<TailorAnalysis> classify({required TailorImage front, TailorImage? back, String source, String? clientRequestId});
  Future<TailorDigitization> digitize({required TailorImage front, TailorImage? back, String source, String? clientRequestId});
  Future<Uint8List> fetchAsset(TailorAssetReference asset);
  Future<Map<String, Object?>> health();
  Future<Map<String, Object?>> readiness();
  Future<Map<String, Object?>> model();
  Future<Map<String, Object?>> categories();
}

class TailorConfig {
  final Uri baseUrl;
  final String apiKey;
  const TailorConfig({required this.baseUrl, required this.apiKey});

  factory TailorConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment('TAILOR_BASE_URL');
    const apiKey = String.fromEnvironment('TAILOR_API_KEY');
    if (baseUrl.isEmpty || apiKey.isEmpty) throw const TailorException(TailorFailureKind.unavailable, 'Tailor is not configured. Enter garment details manually.');
    return TailorConfig(baseUrl: Uri.parse(baseUrl), apiKey: apiKey);
  }
}

abstract interface class TailorCorrectionClient {
  Future<SegmentationCandidate> correct({required TailorImage image, required String view,
    required String sourceHash, required Map<String, Object?> prompts});
}

class TailorClient implements TailorClientBase, TailorCorrectionClient {
  TailorClient(this.config, {http.Client? httpClient, this.timeout = const Duration(seconds: 30)}) : _http = httpClient ?? http.Client();
  final TailorConfig config;
  final http.Client _http;
  final Duration timeout;

  Uri _uri(String path) => config.baseUrl.resolve(path.startsWith('/') ? path.substring(1) : path);

  @override
  Future<TailorAnalysis> classify({required TailorImage front, TailorImage? back, String source = 'mobile_camera', String? clientRequestId}) async {
    final request = http.MultipartRequest('POST', _uri('/api/v1/clothing/classify'))
      ..headers['X-API-Key'] = config.apiKey
      ..fields['source'] = source
      ..files.add(http.MultipartFile.fromBytes('front_image', front.bytes, filename: front.filename));
    if (back != null) request.files.add(http.MultipartFile.fromBytes('back_image', back.bytes, filename: back.filename));
    if (clientRequestId != null) request.fields['client_request_id'] = clientRequestId;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) _throwForStatus(response.statusCode);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      return TailorAnalysis.fromJson(Map<String, Object?>.from(decoded));
    } on TimeoutException {
      throw const TailorException(TailorFailureKind.timeout, 'Tailor took too long. Retry once or enter details manually.');
    } on TailorException {
      rethrow;
    } on FormatException {
      throw const TailorException(TailorFailureKind.malformedResponse, 'Tailor returned an unexpected response. Enter details manually.');
    } on Object {
      throw const TailorException(TailorFailureKind.network, 'Tailor is currently unavailable. Retry or enter garment details manually.');
    }
  }

  @override
  Future<TailorDigitization> digitize({required TailorImage front, TailorImage? back, String source = 'mobile_camera', String? clientRequestId}) async {
    final request = http.MultipartRequest('POST', _uri('/api/v1/clothing/digitize'))
      ..headers['X-API-Key'] = config.apiKey
      ..fields['source'] = source
      ..files.add(http.MultipartFile.fromBytes('front_image', front.bytes, filename: front.filename));
    if (back != null) request.files.add(http.MultipartFile.fromBytes('back_image', back.bytes, filename: back.filename));
    if (clientRequestId != null) request.fields['client_request_id'] = clientRequestId;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) _throwForStatus(response.statusCode);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      return TailorDigitization.fromJson(Map<String, Object?>.from(decoded));
    } on TimeoutException {
      throw const TailorException(TailorFailureKind.timeout, 'Garment preparation took too long. Retry with another image.');
    } on TailorException {
      rethrow;
    } on FormatException {
      throw const TailorException(TailorFailureKind.malformedResponse, 'Tailor returned an unexpected digitization response.');
    } on Object {
      throw const TailorException(TailorFailureKind.network, 'Tailor could not prepare this garment. Retry or continue manually.');
    }
  }

  @override
  Future<Uint8List> fetchAsset(TailorAssetReference asset) async {
    if (_uri(asset.url).origin != config.baseUrl.origin) {
      throw const TailorException(TailorFailureKind.malformedResponse, 'Unsafe asset origin.');
    }
    final response = await _http.get(_uri(asset.url), headers: {'X-API-Key': config.apiKey}).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) _throwForStatus(response.statusCode);
    if (mediaHash(response.bodyBytes) != asset.sha256) {
      throw const TailorException(TailorFailureKind.malformedResponse, 'Asset integrity check failed. Retry preparation.');
    }
    return response.bodyBytes;
  }

  @override
  Future<SegmentationCandidate> correct({required TailorImage image, required String view,
    required String sourceHash, required Map<String, Object?> prompts}) async {
    if (mediaHash(image.bytes) != sourceHash) {
      throw const TailorException(TailorFailureKind.invalidImage, 'Source changed. Analyze the new front image again.');
    }
    final request = http.MultipartRequest('POST', _uri('/api/v1/clothing/digitize/correct'))
      ..headers['X-API-Key'] = config.apiKey
      ..fields.addAll({'view': view, 'source_image_sha256': sourceHash, 'prompts': jsonEncode(prompts)})
      ..files.add(http.MultipartFile.fromBytes('image', image.bytes, filename: image.filename));
    final response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    if (response.statusCode < 200 || response.statusCode >= 300) _throwForStatus(response.statusCode);
    final result = SegmentationCandidate.fromJson(Map<String, Object?>.from(jsonDecode(response.body)['candidate'] as Map));
    if (result.view != view || result.sourceHash != sourceHash) {
      throw const TailorException(TailorFailureKind.malformedResponse, 'Correction identity mismatch.');
    }
    return result;
  }

  @override
  Future<Map<String, Object?>> health() => _get('/healthz');
  @override
  Future<Map<String, Object?>> readiness() => _get('/readyz');
  @override
  Future<Map<String, Object?>> model() => _get('/api/v1/model');
  @override
  Future<Map<String, Object?>> categories() => _get('/api/v1/categories');

  Future<Map<String, Object?>> _get(String path) async {
    try {
      final response = await _http.get(_uri(path)).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) _throwForStatus(response.statusCode);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      return Map<String, Object?>.from(decoded);
    } on TimeoutException {
      throw const TailorException(TailorFailureKind.timeout, 'Tailor took too long.');
    } on TailorException {
      rethrow;
    } on Object {
      throw const TailorException(TailorFailureKind.unavailable, 'Tailor is currently unavailable.');
    }
  }

  Never _throwForStatus(int code) {
    final failure = switch (code) {
      401 => (TailorFailureKind.unauthorized, 'Tailor access is not configured correctly.'),
      413 => (TailorFailureKind.tooLarge, 'This image is too large. Choose a smaller photo.'),
      415 => (TailorFailureKind.unsupportedFormat, 'Use a JPEG, PNG, or WebP image.'),
      422 => (TailorFailureKind.invalidImage, 'This image could not be analyzed. Try another photo or enter the category manually.'),
      429 => (TailorFailureKind.rateLimited, 'Too many requests. Wait a moment, then retry once.'),
      503 => (TailorFailureKind.notReady, 'Tailor is starting or busy. Retry once or enter details manually.'),
      _ when code >= 500 => (TailorFailureKind.server, 'Tailor encountered a server problem. Enter details manually.'),
      _ => (TailorFailureKind.unavailable, 'Tailor could not analyze this image.'),
    };
    throw TailorException(failure.$1, failure.$2, code);
  }
}
