import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/services/tailor_client.dart';
import 'package:textyle_visual_build/services/segmentation_candidate.dart';

Map<String, Object?> responseJson({bool abstained = false}) => {
      'request_id': 'r1',
      'status': abstained ? 'abstained' : 'predicted',
      'prediction': {
        'category': abstained ? 'unknown' : 'long_sleeve_top',
        'confidence': abstained ? .4 : .91,
        'abstained': abstained,
        'top_predictions': [
          {'category': 'long_sleeve_top', 'confidence': .91},
          {'category': 'outerwear', 'confidence': .06},
          {'category': 'short_sleeve_top', 'confidence': .03},
        ],
      },
      'derived_attributes': {'sleeve_type': 'long_sleeve'},
      'model': {'version': '0.1'},
      'warnings': ['back_image_ignored_by_model_v0_1'],
    };

Map<String, Object?> digitizationJson() => {
      'request_id': 'd1',
      'status': 'complete',
      'classification': {
        'category': 'long_sleeve_top',
        'confidence': .91,
        'abstained': false,
        'top_predictions': (responseJson()['prediction'] as Map<String, Object?>)['top_predictions'],
        'sleeve_type': 'long_sleeve',
        'model_version': '0.1',
      },
      'attributes': {
        'primary_color': {'primary_color': 'blue'},
        'pattern': {'value': 'unknown'},
        'suggested_seasons': ['spring', 'fall', 'winter'],
        'layer_role': 'top',
      },
      'assets': {
        'front': {
          'normalized': {'id': 'n', 'url': '/api/v1/digitization/assets/n', 'sha256': mediaHash([1, 2, 3]), 'expires_in_seconds': 900},
          'mask': {'id': 'm', 'url': '/api/v1/digitization/assets/m', 'sha256': 'def', 'expires_in_seconds': 900},
        },
        'back': null,
      },
      'identity': {'front': {'source_image_sha256': 'source', 'normalized_image_sha256': 'abc', 'mask_sha256': 'def'}},
      'readiness': {'classification_ready': true, 'segmentation_ready': true, 'try_on_ready': true, 'three_d_ready': false},
      'processor': {'digitization_version': 'tailor-digitization-v0.1'},
      'warnings': <String>[],
    };

TailorClient client(http.Client httpClient, {Duration timeout = const Duration(seconds: 1)}) => TailorClient(
      TailorConfig(baseUrl: Uri.parse('https://tailor.example/'), apiKey: 'test-key'),
      httpClient: httpClient,
      timeout: timeout,
    );

class InspectClient extends http.BaseClient {
  InspectClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  test('classify sends key, front, optional back, source, and request ID', () async {
    final api = client(InspectClient((request) async {
      expect(request.headers['X-API-Key'], 'test-key');
      expect(request.url.path, '/api/v1/clothing/classify');
      final multipart = request as http.MultipartRequest;
      expect(multipart.files.map((file) => file.field), ['front_image', 'back_image']);
      expect(multipart.fields['source'], 'mobile_camera');
      expect(multipart.fields['client_request_id'], 'client-1');
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(responseJson()))),
        200,
      );
    }));
    final result = await api.classify(
      front: TailorImage(Uint8List.fromList([1]), 'front.jpg'),
      back: TailorImage(Uint8List.fromList([2]), 'back.jpg'),
      source: 'mobile_camera',
      clientRequestId: 'client-1',
    );
    expect(result.prediction.category, GarmentCategory.longSleeveTop);
    expect(result.topPredictions, hasLength(3));
    expect(result.warnings, contains('back_image_ignored_by_model_v0_1'));
  });

  test('front-only request omits back', () async {
    final api = client(InspectClient((request) async {
      expect((request as http.MultipartRequest).files.map((file) => file.field), ['front_image']);
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(responseJson()))),
        200,
      );
    }));
    await api.classify(front: TailorImage(Uint8List(1), 'front.png'), source: 'unknown');
  });

  test('digitize parses assets, attributes, readiness, and fetches with key', () async {
    final api = client(InspectClient((request) async {
      expect(request.headers['X-API-Key'], 'test-key');
      if (request is http.MultipartRequest) {
        expect(request.url.path, '/api/v1/clothing/digitize');
        return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(digitizationJson()))), 200);
      }
      expect(request.url.path, '/api/v1/digitization/assets/n');
      return http.StreamedResponse(Stream.value([1, 2, 3]), 200);
    }));
    final result = await api.digitize(front: TailorImage(Uint8List(1), 'front.png'));
    expect(result.segmentationReady, isTrue);
    expect(result.primaryColor, 'blue');
    expect(result.suggestedSeasons, contains(Season.winter));
    expect(result.sourceImageHash, 'source');
    expect(await api.fetchAsset(result.frontNormalized!), [1, 2, 3]);
  });

  for (final entry in {
    401: TailorFailureKind.unauthorized,
    413: TailorFailureKind.tooLarge,
    415: TailorFailureKind.unsupportedFormat,
    422: TailorFailureKind.invalidImage,
    429: TailorFailureKind.rateLimited,
    503: TailorFailureKind.notReady,
    500: TailorFailureKind.server,
  }.entries) {
    test('maps HTTP ${entry.key}', () async {
      final api = client(MockClient((_) async => http.Response('{}', entry.key)));
      expect(
        () => api.classify(front: TailorImage(Uint8List(1), 'front.jpg'), source: 'unknown'),
        throwsA(isA<TailorException>().having((error) => error.kind, 'kind', entry.value)),
      );
    });
  }

  test('maps timeout and malformed response', () async {
    final slow = client(MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response('{}', 200);
    }), timeout: const Duration(milliseconds: 1));
    expect(() => slow.health(), throwsA(isA<TailorException>().having((e) => e.kind, 'kind', TailorFailureKind.timeout)));
    final malformed = client(MockClient((_) async => http.Response('[]', 200)));
    expect(() => malformed.classify(front: TailorImage(Uint8List(1), 'x'), source: 'unknown'), throwsA(isA<TailorException>().having((e) => e.kind, 'kind', TailorFailureKind.malformedResponse)));
  });

  test('abstention remains a valid unknown result', () async {
    final api = client(MockClient((_) async => http.Response(jsonEncode(responseJson(abstained: true)), 200)));
    final result = await api.classify(front: TailorImage(Uint8List(1), 'x'), source: 'unknown');
    expect(result.abstained, isTrue);
    expect(result.prediction.category, GarmentCategory.unknown);
  });

  test('unexpected category is rejected rather than silently mapped', () async {
    final body = responseJson();
    (body['prediction'] as Map<String, Object?>)['category'] = 'invented_class';
    final api = client(MockClient((_) async => http.Response(jsonEncode(body), 200)));
    expect(
      () => api.classify(front: TailorImage(Uint8List(1), 'x'), source: 'unknown'),
      throwsA(isA<TailorException>().having((e) => e.kind, 'kind', TailorFailureKind.malformedResponse)),
    );
  });
}
