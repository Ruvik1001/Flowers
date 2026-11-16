import 'package:flutter/material.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';
import 'package:flowers/features/sales/domain/entities/sale.dart';

class ShiftDetailPage extends StatelessWidget {
  const ShiftDetailPage({
    super.key,
    required this.shift,
    required this.sales,
    required this.productNames,
  });

  final Shift shift;
  final List<Sale> sales;
  final Map<String, String> productNames;

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  Map<String, double> _paymentTotals() {
    final totals = <String, double>{
      'cash': 0,
      'card': 0,
      'transfer': 0,
    };
    for (final sale in sales) {
      for (final p in sale.payments) {
        totals[p.method] = (totals[p.method] ?? 0) + p.amount;
      }
    }
    return totals;
  }

  double _revenue() => sales.fold<double>(0, (sum, s) => sum + s.total);

  String _lineSummary(Sale sale) {
    if (sale.lines.isEmpty) return 'Без позиций';
    return sale.lines.map((l) {
      final name = productNames[l.productId] ?? 'Товар';
      return '$name × ${l.quantity}';
    }).join(', ');
  }

  String _paymentSummary(Sale sale) {
    if (sale.payments.isEmpty) return '—';
    return sale.payments
        .map((p) => '${Labels.paymentMethod(p.method)} ${formatRub(p.amount)}')
        .join(' · ');
  }

  Widget _metric(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatRub(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payments = _paymentTotals();
    final revenue = _revenue();
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: Text(
        shift.isOpen
            ? 'Открытая смена'
            : 'Смена ${_formatDate(shift.closedAt).split(' ').first}',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SoftCard(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.isOpen ? 'Открыта' : 'Закрыта',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Открыта: ${_formatDate(shift.openedAt)}'),
                if (!shift.isOpen)
                  Text('Закрыта: ${_formatDate(shift.closedAt)}'),
                const SizedBox(height: 12),
                _metric('Ожидалось в кассе', shift.expectedCash ?? shift.inDrawer),
                _metric('Факт', shift.actualCash ?? 0),
                _metric('Расхождение', shift.discrepancy ?? 0),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Выручка по оплатам',
              style: theme.textTheme.titleMedium,
            ),
          ),
          SoftCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _metric('Итого', revenue),
                const Divider(height: 16),
                _metric(Labels.paymentMethod('cash'), payments['cash'] ?? 0),
                _metric(Labels.paymentMethod('card'), payments['card'] ?? 0),
                _metric(
                  Labels.paymentMethod('transfer'),
                  payments['transfer'] ?? 0,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Продажи за смену',
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('За эту смену продаж не было'),
            )
          else
            for (final sale in sales)
              EntityListTile(
                title: Text(formatRub(sale.total)),
                subtitle: Text(
                  '${_lineSummary(sale)}\n${_paymentSummary(sale)}',
                ),
              ),
        ],
      ),
    );
  }
}
