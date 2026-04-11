import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

class TwoGisLauncher {
  const TwoGisLauncher._();

  static Future<void> openRoute({
    required String destinationAddress,
  }) async {
    final trimmed = destinationAddress.trim();
    if (trimmed.isEmpty) {
      throw Exception('Пустой адрес маршрута');
    }

    final encoded = Uri.encodeComponent(trimmed);

    final dgisUri = Uri.parse(
      'dgis://2gis.ru/routeSearch/rsType/car/to/$encoded',
    );

    final webUri = Uri.parse(
      'https://2gis.kz/search/$encoded',
    );

    if (await canLaunchUrl(dgisUri)) {
      final ok = await launchUrl(
        dgisUri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    }

    final ok = await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      throw Exception('Не удалось открыть 2GIS');
    }
  }
}