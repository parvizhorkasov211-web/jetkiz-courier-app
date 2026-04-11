import 'package:jetkiz_courier_app/core/network/apiClient.dart';
import 'package:jetkiz_courier_app/features/orders/domain/courier_order_details.dart';

class CourierOrderDetailsApi {
  const CourierOrderDetailsApi(this._client);

  final ApiClient _client;

  Future<CourierOrderDetails> getOrderDetails(String orderId) async {
    final dynamic response = await _client.get('/orders/courier/$orderId');

    if (response is Map<String, dynamic>) {
      return CourierOrderDetails.fromJson(response);
    }

    if (response is Map) {
      return CourierOrderDetails.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    throw Exception('Некорректный ответ сервера по деталям заказа');
  }

  Future<CourierOrderDetails> markPickedUp(String orderId) async {
    final dynamic response = await _client.patch(
      '/orders/courier/$orderId/status',
      {'status': 'ON_THE_WAY'},
    );

    if (response is Map<String, dynamic>) {
      return CourierOrderDetails.fromJson(response);
    }

    if (response is Map) {
      return CourierOrderDetails.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    throw Exception('Некорректный ответ сервера при смене статуса');
  }

  Future<CourierOrderDetails> markDelivered(String orderId) async {
    final dynamic response = await _client.patch(
      '/orders/courier/$orderId/status',
      {'status': 'DELIVERED'},
    );

    if (response is Map<String, dynamic>) {
      return CourierOrderDetails.fromJson(response);
    }

    if (response is Map) {
      return CourierOrderDetails.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    throw Exception('Некорректный ответ сервера при смене статуса');
  }
}