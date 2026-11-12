import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/core/widgets/line_editor_list.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_state.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';
import 'package:flowers/features/cashier/presentation/cubit/cashier_cubit.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/sales/domain/entities/payment.dart';
import 'package:flowers/features/sales/domain/entities/sale_line.dart';
import 'package:flowers/features/sales/presentation/cubit/sales_cubit.dart';

class CreateSalePage extends StatefulWidget {
  const CreateSalePage({super.key, this.openShift});

  final Shift? openShift;

  @override
  State<CreateSalePage> createState() => _CreateSalePageState();
}

class _CreateSalePageState extends State<CreateSalePage> {
  List<EditableLine> _lines = [];
  List<Product> _products = [];
  var _method = 'cash';
  var _loading = true;
  var _saving = false;
  Shift? _shift;
  final _openingCashCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _shift = widget.openShift;
    _load();
  }

  @override
  void dispose() {
    _openingCashCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final products = await Di.I.catalog.listProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppMessage.showError(context, 'Не удалось загрузить товары');
    }
  }

  double get _total =>
      _lines.fold(0.0, (s, l) => s + l.quantity * l.unitMoney);

  Future<void> _ensureShift(CashierCubit cashier) async {
    if (_shift != null) return;
    final auth = context.read<AuthCubit>().state;
    if (auth is! Authenticated) {
      throw StateError('Требуется авторизация');
    }
    final opening =
        double.tryParse(_openingCashCtrl.text.replaceAll(',', '.')) ?? 0;
    await cashier.open(
      cashierId: auth.user.id,
      openingCash: opening,
    );
    _shift = cashier.state.shifts.where((s) => s.isOpen).firstOrNull;
    if (_shift == null) {
      throw StateError('Не удалось открыть смену');
    }
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      AppMessage.showError(context, 'Добавьте товары в чек');
      return;
    }
    if (_lines.any((l) => l.quantity <= 0)) {
      AppMessage.showError(context, 'Количество должно быть больше 0');
      return;
    }

    final sales = context.read<SalesCubit>();
    final cashier = context.read<CashierCubit>();
    setState(() => _saving = true);
    try {
      if (_shift == null && _method == 'cash') {
        await _ensureShift(cashier);
      }
      final shiftId = _shift?.id;
      final payments = [
        Payment(method: _method, amount: _total),
      ];
      await sales.createSale(
        lines: [
          for (final line in _lines)
            SaleLine(
              productId: line.productId,
              quantity: line.quantity,
              unitPrice: line.unitMoney,
            ),
        ],
        payments: payments,
        shiftId: shiftId,
      );

      if (_method == 'cash' && shiftId != null && _total > 0) {
        try {
          await cashier.cash(
            shiftId: shiftId,
            amount: _total,
          );
        } catch (_) {
          if (mounted) {
            AppMessage.showError(
              context,
              'Продажа создана, но касса не обновлена',
            );
          }
        }
      }

      if (!mounted) return;
      AppMessage.showSuccess(context, 'Чек на ${formatRub(_total)}');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppMessage.showError(
        context,
        sales.state.error ?? e.toString(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: 'Новый чек',
      actionLabel: 'Продать',
      actionLoading: _saving,
      onAction: _saving || _loading ? null : _save,
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SoftCard(
                  child: _shift != null
                      ? Text(
                          'Смена открыта · наличные ${formatRub(_shift!.openingCash + _shift!.cashSales - _shift!.cashRefunds)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Нет открытой смены',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: AppColors.warning),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'При продаже за наличные смена откроется автоматически.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _openingCashCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Наличные в кассе при открытии',
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                LineEditorList(
                  lines: _lines,
                  products: _products,
                  moneyField: LineMoneyField.unitPrice,
                  moneyLabel: 'Цена',
                  onChanged: (next) => setState(() => _lines = next),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _method,
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
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
                const SizedBox(height: 16),
                Text(
                  'Итого: ${formatRub(_total)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
    );
  }
}
