import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_dialog.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_dropdowns.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/photo_upload_field.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
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

class _SalesView extends StatefulWidget {
  const _SalesView();

  @override
  State<_SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<_SalesView> {
  Map<String, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await Di.I.catalog.listProducts(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _productNames = {for (final p in products) p.id: p.name};
      });
    } catch (_) {}
  }

  String _lineSummary(Sale sale) {
    if (sale.lines.isEmpty) return 'Без позиций';
    return sale.lines.map((l) {
      final name = _productNames[l.productId] ?? 'Товар';
      return '$name × ${l.quantity}';
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: const Text('Продажи'),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-sales',
        onPressed: () => _showCreateSaleDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<SalesCubit, SalesState>(
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading && state.sales.isEmpty,
            error: state.error,
            isEmpty: state.sales.isEmpty,
            emptyMessage: 'Нет продаж',
            emptyIcon: Icons.shopping_bag_outlined,
            onRetry: () => context.read<SalesCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: state.sales.length,
              itemBuilder: (context, index) {
                final sale = state.sales[index];
                return EntityListTile(
                  title: Text(formatRub(sale.total)),
                  subtitle: Text(_lineSummary(sale)),
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
    );
  }
}

Future<void> _showCreateSaleDialog(BuildContext context) async {
  List<Product> products;
  List<Shift> shifts;
  try {
    products = await Di.I.catalog.listProducts();
    shifts = await Di.I.cashier.listShifts();
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Не удалось загрузить данные');
    }
    return;
  }
  if (!context.mounted) return;

  String? productId;
  String shiftId = '';
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  var method = 'cash';
  final cubit = context.read<SalesCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новая продажа'),
            content: AppDialogScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProductDropdown(
                    products: products,
                    value: productId,
                    onChanged: (v) {
                      setState(() {
                        productId = v;
                        final product =
                            products.where((p) => p.id == v).firstOrNull;
                        if (product != null && priceCtrl.text.isEmpty) {
                          priceCtrl.text =
                              product.sellPrice.toStringAsFixed(2);
                          final q = double.tryParse(
                                qtyCtrl.text.replaceAll(',', '.'),
                              ) ??
                              0;
                          amountCtrl.text =
                              (q * product.sellPrice).toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Количество'),
                    onChanged: (v) {
                      final q =
                          double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      final p = double.tryParse(
                            priceCtrl.text.replaceAll(',', '.'),
                          ) ??
                          0;
                      amountCtrl.text = (q * p).toStringAsFixed(2);
                    },
                  ),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Цена'),
                    onChanged: (v) {
                      final q = double.tryParse(
                            qtyCtrl.text.replaceAll(',', '.'),
                          ) ??
                          0;
                      final p = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      amountCtrl.text = (q * p).toStringAsFixed(2);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: method,
                    isExpanded: true,
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
                    decoration:
                        const InputDecoration(labelText: 'Сумма оплаты'),
                  ),
                  ShiftDropdown(
                    shifts: shifts,
                    value: shiftId,
                    openOnly: true,
                    allowEmpty: true,
                    onChanged: (v) =>
                        setState(() => shiftId = v ?? ''),
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
  if (productId == null || productId!.isEmpty) {
    if (context.mounted) {
      AppMessage.showError(context, 'Выберите товар');
    }
    return;
  }

  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ??
      (qty * price);

  try {
    await cubit.createSale(
      lines: [
        SaleLine(
          productId: productId!,
          quantity: qty,
          unitPrice: price,
        ),
      ],
      payments: [Payment(method: method, amount: amount)],
      shiftId: shiftId.isEmpty ? null : shiftId,
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
  List<Product> products;
  try {
    products = await Di.I.catalog.listProducts(includeArchived: true);
  } catch (_) {
    products = const [];
  }
  if (!context.mounted) return;

  final amountCtrl =
      TextEditingController(text: sale.total.toStringAsFixed(2));
  var kind = 'money_only';
  String? productId =
      sale.lines.isNotEmpty ? sale.lines.first.productId : null;
  final qtyCtrl = TextEditingController(text: '1');
  List<String> photoIds = [];
  final cubit = context.read<SalesCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Возврат'),
            content: AppDialogScrollBody(
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
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: [
                      DropdownMenuItem(
                        value: 'money_only',
                        child: Text(Labels.refundKind('money_only')),
                      ),
                      DropdownMenuItem(
                        value: 'stock_back',
                        child: Text(Labels.refundKind('stock_back')),
                      ),
                      DropdownMenuItem(
                        value: 'defect_write_off',
                        child: Text(Labels.refundKind('defect_write_off')),
                      ),
                    ],
                    onChanged: (v) => setState(() => kind = v ?? kind),
                  ),
                  if (sale.lines.isNotEmpty)
                    SaleLineProductDropdown(
                      lines: sale.lines,
                      products: products,
                      value: productId,
                      onChanged: (v) => setState(() => productId = v),
                    ),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                  if (kind == 'defect_write_off') ...[
                    const SizedBox(height: 8),
                    PhotoUploadField(
                      fileIds: photoIds,
                      onChanged: (ids) => setState(() => photoIds = ids),
                      minCount: 1,
                    ),
                  ],
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

  if (kind == 'defect_write_off' && photoIds.isEmpty) {
    if (context.mounted) {
      AppMessage.showError(context, 'Нужно приложить хотя бы 1 фото');
    }
    return;
  }

  try {
    await cubit.createRefund(
      saleId: sale.id,
      amount: double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0,
      kind: kind,
      productId: productId,
      quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')),
      photoIds: photoIds,
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
