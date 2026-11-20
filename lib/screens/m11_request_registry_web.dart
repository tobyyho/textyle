import 'package:web/web.dart' as web;

import 'm11_generation_request.dart';

String? m11ReadGenerationRequests() =>
    web.window.localStorage.getItem(m11GenerationRequestsStorageKey);

void m11WriteGenerationRequests(String encoded) =>
    web.window.localStorage.setItem(m11GenerationRequestsStorageKey, encoded);
