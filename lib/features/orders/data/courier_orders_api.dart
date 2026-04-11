import 'package:jetkiz_courier_app/core/network/apiClient.dart';
import 'package:jetkiz_courier_app/features/orders/domain/courier_order_item.dart';

class CourierOrdersApi {
  const CourierOrdersApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CourierOrderItem>> getCourierOrders({
    int page = 1,
    int limit = 100,
    String? status,
    String? from,
    String? to,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };

    final normalizedStatus = (status ?? '').trim();
    if (normalizedStatus.isNotEmpty) {
      query['status'] = normalizedStatus;
    }

    final normalizedFrom = (from ?? '').trim();
    final normalizedTo = (to ?? '').trim();

    if (normalizedFrom.isNotEmpty) {
      query['from'] = normalizedFrom;
    }
    if (normalizedTo.isNotEmpty) {
      query['to'] = normalizedTo;
    }

    final dynamic response = await _apiClient.get(
      _buildPath('/orders/courier/my', query),
    );

    final itemsRaw =
        _extractList(response, const ['items']) ??
        _extractList(response, const ['data', 'items']) ??
        _extractList(response, const ['orders']) ??
        _extractList(response, const ['data', 'orders']) ??
        (response is List ? response : const []);

    return itemsRaw
        .whereType<Map>()
        .map((e) => CourierOrderItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CourierOrderItem?> getActiveOrder() async {
    final dynamic response = await _apiClient.get('/orders/courier/active');

    if (response == null) return null;

    if (response is Map<String, dynamic>) {
      if (response.isEmpty) return null;

      final wrapped =
          _readMap(response, const ['item']) ??
          _readMap(response, const ['data']) ??
          response;

      if (wrapped.isEmpty) return null;

      return CourierOrderItem.fromJson(wrapped);
    }

    if (response is Map) {
      final mapped = Map<String, dynamic>.from(response);
      if (mapped.isEmpty) return null;
      return CourierOrderItem.fromJson(mapped);
    }

    return null;
  }

  String _buildPath(String basePath, Map<String, String> query) {
    if (query.isEmpty) return basePath;

    final uri = Uri(
      path: basePath,
      queryParameters: query,
    );

    return uri.toString();
  }

  static List<dynamic>? _extractList(dynamic json, List<String> path) {
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

  static Map<String, dynamic>? _readMap(dynamic json, List<String> path) {
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

    if (current is Map<String, dynamic>) return current;
    if (current is Map) return Map<String, dynamic>.from(current);
    return null;
  }
}