import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/settings.dart';
import 'recognition_service.dart';

/// Остаток бесплатных запросов у сервиса.
class Quota {
  const Quota({
    required this.remaining,
    required this.total,
    required this.period,
  });

  final int remaining;
  final int total;

  /// «всего» у Plant.id (кредиты не обновляются), «в день» у Pl@ntNet.
  final String period;

  bool get low => remaining <= (total * 0.1).clamp(3, 20);
  bool get exhausted => remaining <= 0;
}

/// Сколько осталось запросов; null — если узнать не удалось (нет ключа, сеть, домен).
final quotaProvider = FutureProvider.family<Quota?, RecognitionProviderId>((
  ref,
  id,
) async {
  final s = ref.watch(settingsProvider);
  if (!s.hasKeyFor(id)) return null;
  try {
    switch (id) {
      case RecognitionProviderId.plantId:
        final res = await http
            .get(
              Uri.parse('https://plant.id/api/v3/usage_info'),
              headers: {'Api-Key': s.plantIdKey},
            )
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) return null;
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final limits = j['credit_limits'] as Map<String, dynamic>;
        final remaining = j['remaining'] as Map<String, dynamic>;
        for (final period in ['day', 'week', 'month', 'total']) {
          if (limits[period] != null && remaining[period] != null) {
            return Quota(
              remaining: (remaining[period] as num).floor(),
              total: (limits[period] as num).round(),
              period: switch (period) {
                'day' => 'в день',
                'week' => 'в неделю',
                'month' => 'в месяц',
                _ => 'всего',
              },
            );
          }
        }
        return null;
      case RecognitionProviderId.plantNet:
        final req = http.Request(
          'GET',
          Uri.parse(
            'https://my-api.plantnet.org/v2/quota/daily?api-key=${s.plantNetKey}',
          ),
        );
        if (!kIsWeb) req.headers['Origin'] = plantNetAppOrigin;
        final res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 12)),
        );
        if (res.statusCode != 200) return null;
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final q = (j['quota'] as Map)['identify'] as Map;
        return Quota(
          remaining: (q['remaining'] as num).toInt(),
          total: (q['total'] as num).toInt(),
          period: 'в день',
        );
    }
  } catch (_) {
    return null;
  }
});
