import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/features/sales/domain/entities/payment.dart';
import 'package:flowers/features/sales/domain/entities/sale.dart';
import 'package:flowers/features/sales/domain/entities/sale_line.dart';
import 'package:flowers/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:flowers/features/sales/presentation/cubit/sales_state.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SalesCubit(Di.I.sales)..load(),
      child: const _SalesView(),
    );
  }
}

class _SalesView extends StatelessWidget {
  const _SalesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Продажи')),
      body: BlocBuilder<SalesCubit, SalesState>(
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading && state.sales.isEmpty,
            error: state.error,
            isEmpty: state.sales.isEmpty,
            emptyMessage: 'Нет продаж',
            onRetry: () => context.read<SalesCubit>().load(),
            child: ListView.separated(
              itemCount: state.sales.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sale = state.sales[index];
                return ListTile(
                  title: Text('Продажа ${sale.id}'),
                  subtitle: Text(
                    '${formatRub(sale.total)} · линий: ${sale.lines.length}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Возврат',
                    onPressed: () => _showRefundDialog(context, sale),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSaleDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _showCreateSaleDialog(BuildContext context) async {
  final productCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  var method = 'cash';
  final shiftCtrl = TextEditingController();
  final cubit = context.read<SalesCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новая продажа'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: productCtrl,
                    decoration: const InputDecoration(labelText: 'ID товара'),
                  ),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Цена'),
                    onChanged: (v) {
                      final q =
                          double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ??
                              0;
                      final p = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      amountCtrl.text = (q * p).toStringAsFixed(2);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'Оплата'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                      DropdownMenuItem(value: 'card', child: Text('Карта')),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Перевод'),
                      ),
                    ],
                    onChanged: (v) => setState(() => method = v ?? method),
                  ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Сумма оплаты'),
                  ),
                  TextField(
                    controller: shiftCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ID смены (опц.)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Продать'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ok != true) return;

  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ??
      (qty * price);

  try {
    await cubit.createSale(
      lines: [
        SaleLine(
          productId: productCtrl.text.trim(),
          quantity: qty,
          unitPrice: price,
        ),
      ],
      payments: [Payment(method: method, amount: amount)],
      shiftId: shiftCtrl.text.trim(),
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Продажа создана');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка продажи');
    }
  }
}

Future<void> _showRefundDialog(BuildContext context, Sale sale) async {
  final amountCtrl = TextEditingController(text: sale.total.toStringAsFixed(2));
  var kind = 'money_only';
  final productCtrl = TextEditingController(
    text: sale.lines.isNotEmpty ? sale.lines.first.productId : '',
  );
  final qtyCtrl = TextEditingController(text: '1');
  final photoCtrl = TextEditingController();
  final cubit = context.read<SalesCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Возврат'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Сумма'),
                  ),
                  DropdownButtonFormField<String>(
                    value: kind,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const [
                      DropdownMenuItem(
                        value: 'money_only',
                        child: Text('Только деньги'),
                      ),
                      DropdownMenuItem(
                        value: 'stock_back',
                        child: Text('На склад'),
                      ),
                      DropdownMenuItem(
                        value: 'defect_write_off',
                        child: Text('Брак'),
                      ),
                    ],
                    onChanged: (v) => setState(() => kind = v ?? kind),
                  ),
                  TextField(
                    controller: productCtrl,
                    decoration: const InputDecoration(labelText: 'ID товара'),
                  ),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                  TextField(
                    controller: photoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ID фото (через запятую)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Вернуть'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ok != true) return;

  try {
    await cubit.createRefund(
      saleId: sale.id,
      amount: double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0,
      kind: kind,
      productId: productCtrl.text.trim(),
      quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')),
      photoIds: photoCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Возврат оформлен');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка возврата');
    }
  }
}
