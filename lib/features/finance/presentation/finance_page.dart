import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_courier_app/core/network/apiClient.dart';
import 'package:jetkiz_courier_app/features/finance/data/courier_finance_api.dart';
import 'package:jetkiz_courier_app/features/finance/domain/courier_finance_models.dart';
import 'package:jetkiz_courier_app/features/home/home_page.dart';
import 'package:jetkiz_courier_app/features/navigation/navigation_presentation/widgets/courier_bottom_bar.dart';
import 'package:jetkiz_courier_app/features/orders/presentation/orders_page.dart';
import 'package:jetkiz_courier_app/features/profile/presentation/profile_page.dart';

enum FinancePeriod {
  today,
  yesterday,
  week,
  month,
  custom,
}

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with WidgetsBindingObserver {
  late final CourierFinanceApi _api;

  Timer? _pollTimer;

  FinancePeriod _period = FinancePeriod.month;
  bool _showDatePicker = false;
  String _customStartDate = '';
  String _customEndDate = '';

  bool _isForeground = true;
  bool _loading = true;
  bool _polling = false;
  bool _loadedOnce = false;

  String? _error;
  CourierFinanceResponse? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = CourierFinanceApi(ApiClient());
    _loadFinance();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isForeground;
    _isForeground = state == AppLifecycleState.resumed;

    if (!wasForeground && _isForeground) {
      _silentRefresh(force: true);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _silentRefresh({bool force = false}) async {
    if (!_isForeground && !force) return;
    if (_loading || _polling) return;

    _polling = true;

    try {
      final result = await _api.getFinance(
        period: _periodToApiValue(_period),
        startDate: _period == FinancePeriod.custom ? _customStartDate : null,
        endDate: _period == FinancePeriod.custom ? _customEndDate : null,
      );

      if (!mounted) return;

      setState(() {
        _data = result;
        _error = null;
        _loadedOnce = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось обновить финансы';
      });
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadFinance() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.getFinance(
        period: _periodToApiValue(_period),
        startDate: _period == FinancePeriod.custom ? _customStartDate : null,
        endDate: _period == FinancePeriod.custom ? _customEndDate : null,
      );

      if (!mounted) return;

      setState(() {
        _data = result;
        _loading = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить финансы: $e';
        _loading = false;
      });
    }
  }

  String _periodToApiValue(FinancePeriod period) {
    switch (period) {
      case FinancePeriod.today:
        return 'today';
      case FinancePeriod.yesterday:
        return 'yesterday';
      case FinancePeriod.week:
        return 'week';
      case FinancePeriod.month:
        return 'month';
      case FinancePeriod.custom:
        return 'custom';
    }
  }

  void _handlePeriodChange(FinancePeriod newPeriod) {
    setState(() {
      _period = newPeriod;
      _showDatePicker = newPeriod == FinancePeriod.custom;
    });

    if (newPeriod != FinancePeriod.custom) {
      _loadFinance();
    }
  }

  void _applyCustomDateRange() {
    if (_customStartDate.isEmpty || _customEndDate.isEmpty) return;

    setState(() {
      _showDatePicker = false;
    });

    _loadFinance();
  }

  String _periodLabel() {
    switch (_period) {
      case FinancePeriod.today:
        return 'Сегодня';
      case FinancePeriod.yesterday:
        return 'Вчера';
      case FinancePeriod.week:
        return '7 дней';
      case FinancePeriod.month:
        return '30 дней';
      case FinancePeriod.custom:
        return 'Период';
    }
  }

  String _formatMoney(num value) {
    final intValue = value.round();
    final negative = intValue < 0;
    final abs = intValue.abs().toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = abs.length - 1; i >= 0; i--) {
      buffer.write(abs[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(' ');
      }
    }

    final text = buffer.toString().split('').reversed.join();
    return '${negative ? '-' : ''}$text ₸';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final d = value.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day.$month.$year';
  }

  String _formatDateTime(DateTime value) {
    final d = value.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year  $hour:$minute';
  }

  void _onBottomBarTap(int index) {
    if (index == 2) return;

    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
      );
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OrdersPage(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ProfilePage(),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8F8FA);
    const accent = Color(0xFF489F2A);

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: CourierBottomBar(
        currentIndex: 2,
        onTap: _onBottomBarTap,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: bg,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE4E8EF),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Финансы',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FinancePeriodTabs(
                    selectedPeriod: _period,
                    onChanged: _handlePeriodChange,
                  ),
                  if (_showDatePicker) ...[
                    const SizedBox(height: 12),
                    _FinanceCustomPeriodPicker(
                      startDate: _customStartDate,
                      endDate: _customEndDate,
                      onStartChanged: (value) {
                        setState(() {
                          _customStartDate = value;
                        });
                      },
                      onEndChanged: (value) {
                        setState(() {
                          _customEndDate = value;
                        });
                      },
                      onApply: _applyCustomDateRange,
                    ),
                  ],
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    opacity: _polling ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Обновляется...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && !_loadedOnce
                  ? const Center(child: CircularProgressIndicator(color: accent))
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final data = _data;

    if (data == null && _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (data == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: const Color(0xFF489F2A),
          onRefresh: _loadFinance,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _FinanceRevenueCard(
                title: 'К выводу',
                amount: data.availableToWithdraw,
                subtitle: 'За ${_periodLabel().toLowerCase()}',
                money: _formatMoney,
              ),
              const SizedBox(height: 12),
              _FinanceBalancesCard(
                availableAmount: data.availableToWithdraw,
                inPayoutAmount: data.assignedButUnpaidAmount,
                paidAmount: data.paidAmount,
                accruedAmount: data.payoutAmount,
                money: _formatMoney,
              ),
              const SizedBox(height: 12),
              _FinanceStatsGrid(
                deliveredOrdersCount: data.deliveredOrdersCount,
                grossIncome: data.grossIncome,
                commissionAmount: data.commissionAmount,
                bonusesAmount: data.bonusesAmount,
                deductionsAmount: data.deductionsAmount,
                money: _formatMoney,
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                title: 'История операций',
                trailing: '${data.ledger.length}',
              ),
              const SizedBox(height: 10),
              if (data.ledger.isEmpty)
                const _EmptyCard(
                  title: 'Операций пока нет',
                  subtitle: 'Здесь появятся начисления, выплаты и корректировки',
                )
              else
                ...data.ledger.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LedgerCard(
                      item: item,
                      money: _formatMoney,
                      dateTime: _formatDateTime,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _FinanceSummarySection(
                periodLabel: _periodLabel(),
                data: data,
                money: _formatMoney,
                date: _formatDate,
              ),
            ],
          ),
        ),
        if (_error != null && _loadedOnce)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF1C4C4),
                    width: 1.2,
                  ),
                ),
                child: const Text(
                  'Не удалось обновить финансы. Повторим автоматически.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FinancePeriodTabs extends StatelessWidget {
  const _FinancePeriodTabs({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final FinancePeriod selectedPeriod;
  final ValueChanged<FinancePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({FinancePeriod value, String label})>[
      (value: FinancePeriod.today, label: 'Сегодня'),
      (value: FinancePeriod.yesterday, label: 'Вчера'),
      (value: FinancePeriod.week, label: '7 дней'),
      (value: FinancePeriod.month, label: '30 дней'),
      (value: FinancePeriod.custom, label: 'Период'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final selected = selectedPeriod == item.value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(item.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF489F2A) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF489F2A)
                        : const Color(0xFFD0D5DD),
                  ),
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF344054),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinanceCustomPeriodPicker extends StatelessWidget {
  const _FinanceCustomPeriodPicker({
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onApply,
  });

  final String startDate;
  final String endDate;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'От',
                  value: startDate,
                  onChanged: onStartChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'До',
                  value: endDate,
                  onChanged: onEndChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Применить',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '2026-04-06',
        hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
        labelStyle: const TextStyle(color: Color(0xFF667085)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF489F2A)),
        ),
      ),
    );
  }
}

class _FinanceRevenueCard extends StatelessWidget {
  const _FinanceRevenueCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.money,
  });

  final String title;
  final int amount;
  final String subtitle;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF489F2A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            money(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceBalancesCard extends StatelessWidget {
  const _FinanceBalancesCard({
    required this.availableAmount,
    required this.inPayoutAmount,
    required this.paidAmount,
    required this.accruedAmount,
    required this.money,
  });

  final int availableAmount;
  final int inPayoutAmount;
  final int paidAmount;
  final int accruedAmount;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        children: [
          _BalanceRow(
            label: 'Доступно к выводу',
            value: money(availableAmount),
            valueColor: const Color(0xFF489F2A),
          ),
          const SizedBox(height: 10),
          _BalanceRow(
            label: 'В обработке выплаты',
            value: money(inPayoutAmount),
          ),
          const SizedBox(height: 10),
          _BalanceRow(
            label: 'Уже выплачено',
            value: money(paidAmount),
          ),
          const SizedBox(height: 10),
          _BalanceRow(
            label: 'Всего начислено',
            value: money(accruedAmount),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.black,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FinanceStatsGrid extends StatelessWidget {
  const _FinanceStatsGrid({
    required this.deliveredOrdersCount,
    required this.grossIncome,
    required this.commissionAmount,
    required this.bonusesAmount,
    required this.deductionsAmount,
    required this.money,
  });

  final int deliveredOrdersCount;
  final int grossIncome;
  final int commissionAmount;
  final int bonusesAmount;
  final int deductionsAmount;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    final items = <_StatTileData>[
      _StatTileData(
        title: 'Доставок',
        value: '$deliveredOrdersCount',
      ),
      _StatTileData(
        title: 'Начислено',
        value: money(grossIncome),
      ),
      _StatTileData(
        title: 'Комиссия/удержания',
        value: money(commissionAmount + deductionsAmount),
      ),
      _StatTileData(
        title: 'Бонусы',
        value: money(bonusesAmount),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4E8EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(
                color: Color(0xFF475467),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.item,
    required this.money,
    required this.dateTime,
  });

  final CourierFinanceLedgerItem item;
  final String Function(num value) money;
  final String Function(DateTime value) dateTime;

  @override
  Widget build(BuildContext context) {
    final type = item.type.trim().toUpperCase();
    final positive = item.amount >= 0;
    final amountColor = positive
        ? const Color(0xFF489F2A)
        : const Color(0xFFD92D20);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _ledgerTitle(type),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                positive ? '+${money(item.amount)}' : money(item.amount),
                style: TextStyle(
                  color: amountColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if ((item.note ?? '').trim().isNotEmpty) ...[
            Text(
              item.note!,
              style: const TextStyle(
                color: Color(0xFF475467),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  dateTime(item.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item.orderNumber != null)
                Text(
                  'Заказ #${item.orderNumber}',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _ledgerTitle(String type) {
    switch (type) {
      case 'ORDER_PAYOUT':
        return 'Начисление за заказ';
      case 'BONUS':
        return 'Бонус';
      case 'PAYOUT':
        return 'Выплата';
      case 'DEDUCTION':
        return 'Удержание';
      case 'MANUAL_ADJUSTMENT':
        return 'Корректировка';
      default:
        return 'Финансовая операция';
    }
  }
}

class _FinanceSummarySection extends StatelessWidget {
  const _FinanceSummarySection({
    required this.periodLabel,
    required this.data,
    required this.money,
    required this.date,
  });

  final String periodLabel;
  final CourierFinanceResponse data;
  final String Function(num value) money;
  final String Function(DateTime? value) date;

  @override
  Widget build(BuildContext context) {
    final firstDate = data.ledger.isEmpty
        ? null
        : data.ledger.last.createdAt;
    final lastDate = data.ledger.isEmpty
        ? null
        : data.ledger.first.createdAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итог за $periodLabel',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Начислено',
            value: money(data.grossIncome),
          ),
          _DetailRow(
            label: 'Выплачено',
            value: money(data.paidAmount),
          ),
          _DetailRow(
            label: 'Доступно',
            value: money(data.availableToWithdraw),
          ),
          _DetailRow(
            label: 'Операций',
            value: '${data.ledger.length}',
          ),
          _DetailRow(
            label: 'Период операций',
            value: '${date(firstDate)} — ${date(lastDate)}',
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF98A2B3),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}