import 'package:jetkiz_courier_app/core/network/apiClient.dart';
import 'package:jetkiz_courier_app/features/finance/domain/courier_finance_models.dart';

class CourierFinanceApi {
  const CourierFinanceApi(this._apiClient);

  final ApiClient _apiClient;

  Future<CourierFinanceResponse> getFinance({
    String period = '30d',
    String? startDate,
    String? endDate,
  }) async {
    final resolvedPeriod = _mapUiPeriodToBackend(period);

    final query = <String, String>{
      'period': resolvedPeriod,
    };

    if (resolvedPeriod == 'custom') {
      final from = (startDate ?? '').trim();
      final to = (endDate ?? '').trim();

      if (from.isEmpty || to.isEmpty) {
        throw ArgumentError(
          'startDate and endDate are required for custom period',
        );
      }

      query['from'] = from;
      query['to'] = to;
    }

    final summaryPath = _buildPath(
      '/couriers/me/finance/summary',
      query,
    );

    final ledgerPath = _buildPath(
      '/couriers/me/finance/ledger',
      {
        ...query,
        'page': '1',
        'limit': '200',
      },
    );

    final summaryResponse = await _apiClient.get(summaryPath);
    final ledgerResponse = await _apiClient.get(ledgerPath);

    final summaryJson = _asMap(summaryResponse);
    final ledgerItems =
        _extractList(ledgerResponse, const ['items']) ??
        _extractList(ledgerResponse, const ['data', 'items']) ??
        _extractList(ledgerResponse, const ['ledger']) ??
        _extractList(ledgerResponse, const ['data', 'ledger']) ??
        (ledgerResponse is List ? ledgerResponse : const []);

    return CourierFinanceResponse.fromParts(
      periodKey: resolvedPeriod,
      summaryJson: summaryJson,
      ledgerJson: ledgerItems,
    );
  }

  String _buildPath(String basePath, Map<String, String> query) {
    if (query.isEmpty) return basePath;

    final uri = Uri(
      path: basePath,
      queryParameters: query,
    );

    return uri.toString();
  }

  String _mapUiPeriodToBackend(String value) {
    switch (value.trim().toLowerCase()) {
      case 'today':
        return 'today';
      case 'yesterday':
        return 'yesterday';
      case 'week':
      case '7d':
        return '7d';
      case 'month':
      case '30d':
        return '30d';
      case 'custom':
        return 'custom';
      default:
        return '30d';
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic>? _extractList(dynamic json, List<String> path) {
    dynamic current = json;

    for (final part in path) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current is List ? current : null;
  }
}