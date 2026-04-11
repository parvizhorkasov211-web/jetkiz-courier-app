import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jetkiz_courier_app/core/network/apiClient.dart';
import 'package:jetkiz_courier_app/core/services/two_gis_launcher.dart';
import 'package:jetkiz_courier_app/features/orders/data/courier_order_details_api.dart';
import 'package:jetkiz_courier_app/features/orders/domain/courier_order_details.dart';
import 'package:jetkiz_courier_app/features/orders/presentation/widgets/order_items_card.dart';
import 'package:jetkiz_courier_app/features/orders/presentation/widgets/order_party_card.dart';
import 'package:jetkiz_courier_app/features/orders/presentation/widgets/order_status_timer_card.dart';

class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late final CourierOrderDetailsApi _api;
  Timer? _timer;

  CourierOrderDetails? _order;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _error = '';
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _api = CourierOrderDetailsApi(ApiClient());
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final order = await _api.getOrderDetails(widget.orderId);

      if (!mounted) return;

      setState(() {
        _order = order;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить детали заказа';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _callPhone(String? phone) async {
    final raw = (phone ?? '').trim();
    if (raw.isEmpty) {
      _showSnackBar('Телефон не указан');
      return;
    }

    final uri = Uri.parse('tel:$raw');
    final ok = await launchUrl(uri);
    if (!ok) {
      _showSnackBar('Не удалось открыть звонок');
    }
  }

  Future<void> _openTwoGis(String? address) async {
    final raw = (address ?? '').trim();
    if (raw.isEmpty) {
      _showSnackBar('Адрес не указан');
      return;
    }

    try {
      await TwoGisLauncher.openRoute(destinationAddress: raw);
    } catch (_) {
      _showSnackBar('Не удалось открыть маршрут в 2GIS');
    }
  }

  Future<void> _submitMainAction() async {
    final order = _order;
    if (order == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      CourierOrderDetails updated;

      if (order.canMarkPickedUp) {
        updated = await _api.markPickedUp(order.id);
      } else if (order.canMarkDelivered) {
        updated = await _api.markDelivered(order.id);
      } else {
        _showSnackBar('Для этого статуса действие недоступно');
        return;
      }

      if (!mounted) return;

      setState(() {
        _order = updated;
      });

      final message = updated.isDelivered
          ? 'Заказ доставлен'
          : updated.isOnTheWay
              ? 'Заказ забран из ресторана'
              : 'Статус заказа обновлён';

      _showSnackBar(message);

      if (updated.isDelivered) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      _showSnackBar('Не удалось обновить статус заказа');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _mainActionLabel(CourierOrderDetails order) {
    if (order.canMarkPickedUp) return 'Забрал заказ';
    if (order.canMarkDelivered) return 'Доставил';
    return 'Действие недоступно';
  }

  int _resolveCourierIncome(CourierOrderDetails order) {
    if (order.courierFee != null) {
      return order.courierFee!;
    }

    if (order.courierFeeGross != null &&
        order.courierCommissionAmount != null) {
      return order.courierFeeGross! - order.courierCommissionAmount!;
    }

    return order.courierFeeGross ?? 0;
  }

  String _formatMoney(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(' ');
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8F8FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: bg,
        title: Text(
          _order == null ? 'Заказ' : 'Заказ №${_order!.number}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Не удалось загрузить детали заказа',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order;
    if (order == null) {
      return const Center(
        child: Text('Заказ не найден'),
      );
    }

    final income = _formatMoney(_resolveCourierIncome(order));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          OrderStatusTimerCard(
            order: order,
            now: _now,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FBF1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFB7E3B1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ваш доход',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$income ₸',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F8731),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OrderPartyCard(
            title: 'Ресторан',
            name: order.restaurantName,
            address: order.restaurantAddress,
            phone: order.restaurantPhone,
            onCallTap: () => _callPhone(order.restaurantPhone),
            onRouteTap: () => _openTwoGis(order.restaurantAddress),
          ),
          const SizedBox(height: 16),
          OrderPartyCard(
            title: 'Клиент',
            name: order.clientName,
            address: order.clientAddress,
            phone: order.clientPhone,
            comment: order.clientComment,
            leaveAtDoor: order.leaveAtDoor,
            onCallTap: () => _callPhone(order.clientPhone),
            onRouteTap: () => _openTwoGis(order.clientAddress),
          ),
          const SizedBox(height: 16),
          OrderItemsCard(items: order.items),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget? _buildBottomAction() {
    final order = _order;
    if (order == null) return null;
    if (order.isDelivered || order.isCanceled) return null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitMainAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F8731),
              disabledBackgroundColor: const Color(0xFF98A2B3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _mainActionLabel(order),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}