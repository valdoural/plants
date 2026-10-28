import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../models.dart';
import '../../core/photo_normalize.dart';
import 'plant_id_parser.dart';
import 'plantnet_parser.dart';

/// Что изображено на фото — подсказка для Pl@ntNet.
enum PlantOrgan {
  auto('Авто'),
  leaf('Лист'),
  flower('Цветок'),
  fruit('Плод'),
  bark('Кора');

  const PlantOrgan(this.label);
  final String label;
}

enum RecognitionErrorKind {
  limit,
  key,
  domain,
  network,
  timeout,
  emptyPhoto,
  server,
}

class RecognitionException implements Exception {
  RecognitionException(
    this.message, {
    this.provider,
    this.kind = RecognitionErrorKind.server,
    this.detail,
  });

  /// Коротко, для всплывающего сообщения.
  final String message;
  final RecognitionErrorKind kind;

  /// Технические подробности (код ответа, текст ошибки) — для «Подробнее».
  final String? detail;

  /// Какой сервис не ответил — чтобы предложить попробовать другой.
  final RecognitionProviderId? provider;
  @override
  String toString() => detail == null ? message : '$message ($detail)';
}

final recognitionServiceProvider = Provider<RecognitionService>((ref) {
  return RecognitionService(
    ref.watch(settingsProvider),
    ref.watch(supabaseReadyProvider),
  );
});

/// Единая точка входа: распознавание вида и диагностика.
/// Запросы идут напрямую с ключом из настроек или через Edge Function `recognize`.
/// Адрес web-версии — его же нужно указать в my.plantnet.org → Authorized domains.
const plantNetAppOrigin = 'https://valdoural.github.io';

class RecognitionService {
  RecognitionService(this.settings, this.supabaseReady);

  final AppSettings settings;
  final bool supabaseReady;

  static const _plantIdBase = 'https://plant.id/api/v3';
  static const _plantNetBase = 'https://my-api.plantnet.org/v2/identify/all';
  static const _plantIdDetails =
      'common_names,url,description,taxonomy,image,watering,best_watering,best_light_condition,best_soil_type,toxicity,gbif_id';
  static const _healthDetails =
      'local_name,description,treatment,cause,common_names';

  bool get _viaProxy => settings.useServerProxy && supabaseReady;

  Future<IdentificationResult> identify(
    List<Uint8List> images, {
    RecognitionProviderId? provider,
    PlantOrgan organ = PlantOrgan.auto,
  }) async {
    final id = provider ?? settings.provider;
    _requireKey(id);
    images = await _normalize(images);
    switch (id) {
      case RecognitionProviderId.plantId:
        final json = await _plantIdPost(
          'identification',
          {'details': _plantIdDetails},
          {'images': images.map(_dataUri).toList(), 'similar_images': true},
        );
        return parsePlantIdIdentification(json);
      case RecognitionProviderId.plantNet:
        final json = await _plantNetIdentify(images, organ);
        return parsePlantNet(json);
    }
  }

  Future<HealthResult> diagnose(List<Uint8List> images) async {
    if (!settings.canDiagnose) {
      throw RecognitionException(
        'Нужен ключ Plant.id — добавьте его в настройках.',
        kind: RecognitionErrorKind.key,
      );
    }
    images = await _normalize(images);
    final json = await _plantIdPost(
      'health_assessment',
      {'details': _healthDetails},
      {'images': images.map(_dataUri).toList(), 'similar_images': true},
    );
    return parsePlantIdHealth(json);
  }

  void _requireKey(RecognitionProviderId id) {
    if (!settings.hasKeyFor(id)) {
      throw RecognitionException(
        'Нет ключа ${id.short} — добавьте его в настройках.',
        kind: RecognitionErrorKind.key,
        provider: id,
      );
    }
  }

  /// Любой снимок (HEIC с iPhone, PNG, огромный кадр) → JPEG до 1280 px; пустой кадр — понятная ошибка.
  Future<List<Uint8List>> _normalize(List<Uint8List> images) async {
    final out = <Uint8List>[];
    for (final b in images) {
      try {
        out.add(await normalizePhoto(b));
      } on BlankPhotoException {
        throw RecognitionException(
          'Снимок получился пустым — снимите ещё раз.',
          kind: RecognitionErrorKind.emptyPhoto,
        );
      } catch (e) {
        throw RecognitionException(
          'Не удалось прочитать фото — выберите другое.',
          kind: RecognitionErrorKind.emptyPhoto,
          detail: '$e',
        );
      }
    }
    return out;
  }

  String _dataUri(Uint8List bytes) =>
      'data:${imageMimeType(bytes)};base64,${base64Encode(bytes)}';

  Future<Map<String, dynamic>> _plantIdPost(
    String endpoint,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) async {
    final q = {...query, 'language': settings.language};
    if (_viaProxy) {
      return _invokeProxy({
        'provider': 'plantid',
        'endpoint': endpoint,
        'query': q,
        'body': body,
      });
    }
    final uri = Uri.parse('$_plantIdBase/$endpoint')
        .replace(queryParameters: q);
    final res = await _send(
      RecognitionProviderId.plantId,
      () => http.post(
        uri,
        headers: {
          'Api-Key': settings.plantIdKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
    return _decode(res, 'Plant.id');
  }

  Future<Map<String, dynamic>> _plantNetIdentify(
    List<Uint8List> images,
    PlantOrgan organ,
  ) async {
    final q = {
      'lang': settings.language,
      'include-related-images': 'true',
      'nb-results': '5',
    };
    if (_viaProxy) {
      return _invokeProxy({
        'provider': 'plantnet',
        'query': q,
        'images': images.map(base64Encode).toList(),
        'organs': List.filled(images.length, organ.name),
      });
    }
    final uri = Uri.parse(_plantNetBase)
        .replace(queryParameters: {...q, 'api-key': settings.plantNetKey});
    final req = http.MultipartRequest('POST', uri);
    // Ключ Pl@ntNet с включённым «Expose API key» принимает только запросы с разрешённых сайтов.
    // В приложении для телефона браузера нет, поэтому представляемся адресом нашего сайта —
    // тогда один и тот же ключ работает и в web-версии, и в Android/iOS.
    if (!kIsWeb) req.headers['Origin'] = plantNetAppOrigin;
    for (var i = 0; i < images.length; i++) {
      final mime = imageMimeType(images[i]);
      req.files.add(
        http.MultipartFile.fromBytes(
          'images',
          images[i],
          filename: 'photo$i.${mime.split('/').last}',
          contentType: MediaType.parse(mime),
        ),
      );
      req.files.add(http.MultipartFile.fromString('organs', organ.name));
    }
    final res = await _send(
      RecognitionProviderId.plantNet,
      () async => http.Response.fromStream(await req.send()),
    );
    if (res.statusCode == 404) return {'results': []}; // «Species not found»
    return _decode(res, 'Pl@ntNet');
  }

  Future<Map<String, dynamic>> _invokeProxy(Map<String, dynamic> body) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'recognize',
        body: body,
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      throw RecognitionException(
        'Сервер распознавания не ответил.',
        detail: 'HTTP ${e.status}: ${e.details ?? e.reasonPhrase}',
      );
    }
  }

  Future<http.Response> _send(
    RecognitionProviderId id,
    Future<http.Response> Function() call,
  ) async {
    try {
      return await call().timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw RecognitionException(
        '${id.short} не ответил вовремя.',
        provider: id,
        kind: RecognitionErrorKind.timeout,
        detail: 'нет ответа за 45 с',
      );
    } on http.ClientException catch (e) {
      // В браузере отказ по CORS выглядит как обрыв связи — для Pl@ntNet это почти всегда неразрешённый домен.
      if (kIsWeb && id == RecognitionProviderId.plantNet) {
        throw _plantNetDomain(e.message);
      }
      throw RecognitionException(
        'Нет связи с ${id.short}.',
        provider: id,
        kind: RecognitionErrorKind.network,
        detail: e.message,
      );
    }
  }

  RecognitionException _plantNetDomain([
    String? detail,
  ]) => RecognitionException(
    'Pl@ntNet не пускает этот сайт.',
    provider: RecognitionProviderId.plantNet,
    kind: RecognitionErrorKind.domain,
    detail:
        'В my.plantnet.org → Authorized domains нужно «${Uri.base.scheme}://${Uri.base.host}» (вместе с https://)'
        '${detail == null ? '' : '. $detail'}',
  );

  Map<String, dynamic> _decode(http.Response res, String name) {
    final id = name == 'Pl@ntNet'
        ? RecognitionProviderId.plantNet
        : RecognitionProviderId.plantId;
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    final code = res.statusCode;
    final detail =
        'HTTP $code: ${body.length > 200 ? body.substring(0, 200) : body}';
    final lower = body.toLowerCase();
    if (code == 429 ||
        code == 402 ||
        (code >= 400 &&
            (lower.contains('credit') ||
                lower.contains('quota') ||
                lower.contains('limit')))) {
      throw RecognitionException(
        'Лимит $name исчерпан.',
        provider: id,
        kind: RecognitionErrorKind.limit,
        detail: detail,
      );
    }
    if (id == RecognitionProviderId.plantNet &&
        code == 403 &&
        (lower.contains('origin') || lower.contains('remote ip') || kIsWeb)) {
      throw _plantNetDomain(detail);
    }
    if (code == 401 || code == 403) {
      throw RecognitionException(
        '$name не принял ключ.',
        provider: id,
        kind: RecognitionErrorKind.key,
        detail: detail,
      );
    }
    if (code >= 400) {
      throw RecognitionException(
        '$name вернул ошибку $code.',
        provider: id,
        detail: detail,
      );
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map,
    );
  }
}

/// Тип картинки по первым байтам: браузер может отдать JPEG, PNG, WebP или HEIC.
String imageMimeType(Uint8List b) {
  bool at(int offset, List<int> sig) =>
      b.length >= offset + sig.length &&
      [for (var i = 0; i < sig.length; i++) b[offset + i] == sig[i]]
          .every((x) => x);
  if (at(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
    return 'image/webp';
  }
  if (at(4, [0x66, 0x74, 0x79, 0x70])) return 'image/heic'; // ftyp…: HEIC/HEIF
  return 'image/jpeg';
}
