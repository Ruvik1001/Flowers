import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_dialog.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_state.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';
import 'package:flowers/features/cashier/presentation/cubit/cashier_cubit.dart';
import 'package:flowers/features/cashier/presentation/cubit/cashier_state.dart';
import 'package:flowers/features/sales/domain/entities/sale.dart';
import 'package:flowers/features/sales/presentation/cubit/sales_cubit.dart';
import 'package:flowers/features/sales/presentation/cubit/sales_state.dart';
import 'package:flowers/features/sales/presentation/pages/create_sale_page.dart';
import 'package:flowers/features/sales/presentation/pages/refund_sale_page.dart';

class PosHubPage extends StatelessWidget {
  const PosHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SalesCubit(Di.I.sales)..load()),
        BlocProvider(create: (_) => CashierCubit(Di.I.cashier)..load()),
      ],
      child: const _PosHubView(),
    );
  }
}

class _PosHubView extends StatefulWidget {
  const _PosHubView();

  @override
  State<_PosHubView> createState() => _PosHubViewState();
}

class _PosHubViewState extends State<_PosHubView> {
  Map<String, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    _loadProductNames();
  }

  Future<void> _loadProductNames() async {
    try {
      final products = await Di.I.catalog.listProducts(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _productNames = {for (final p in products) p.id: p.name};
      });
    } catch (_) {}
  }

  Shift? _openShift(CashierState state) =>
      state.shifts.where((s) => s.isOpen).firstOrNull;

  String _lineSummary(Sale sale) {
    if (sale.lines.isEmpty) return 'Без позиций';
    return sale.lines.map((l) {
      final name = _productNames[l.productId] ?? 'Товар';
      return '$name × ${l.quantity}';
    }).join(', ');
  }

  Future<void> _openSale(Shift? openShift) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<SalesCubit>()),
            BlocProvider.value(value: context.read<CashierCubit>()),
            BlocProvider.value(value: context.read<AuthCubit>()),
          ],
          child: CreateSalePage(openShift: openShift),
        ),
      ),
    );
  }

  Future<void> _openRefund(Sale sale, String? openShiftId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<SalesCubit>()),
            BlocProvider.value(value: context.read<CashierCubit>()),
          ],
          child: RefundSalePage(sale: sale, openShiftId: openShiftId),
        ),
      ),
    );
  }

  Future<void> _openShiftDialog() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is! Authenticated) {
      AppMessage.showError(context, 'Требуется авторизация');
      return;
    }
    final cashCtrl = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Открыть смену'),
        content: AppDialogScrollBody(
          child: TextField(
            controller: cashCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Наличные в кассе'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final cashier = context.read<CashierCubit>();
    try {
      await cashier.open(
        cashierId: auth.user.id,
        openingCash:
            double.tryParse(cashCtrl.text.replaceAll(',', '.')) ?? 0,
      );
      if (mounted) AppMessage.showSuccess(context, 'Смена открыта');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(
          context,
          cashier.state.error ?? 'Ошибка',
        );
      }
    }
  }

  Future<void> _closeShift(Shift shift) async {
    final expected = shift.expectedCash ??
        (shift.openingCash + shift.cashSales - shift.cashRefunds);
    final ctrl = TextEditingController(text: expected.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Закрыть смену'),
        content: AppDialogScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ожидается: ${formatRub(expected)}'),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Факт наличных'),
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
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final cashier = context.read<CashierCubit>();
    try {
      await cashier.closeShift(
        shiftId: shift.id,
        actualCash: double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0,
      );
      if (mounted) AppMessage.showSuccess(context, 'Смена закрыта');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(
          context,
          cashier.state.error ?? 'Ошибка',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: const Text('Касса'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-pos',
        onPressed: () {
          final open = _openShift(context.read<CashierCubit>().state);
          _openSale(open);
        },
        icon: const Icon(Icons.point_of_sale),
        label: const Text('Чек'),
      ),
      body: BlocBuilder<CashierCubit, CashierState>(
        builder: (context, cashierState) {
          final open = _openShift(cashierState);
          return BlocBuilder<SalesCubit, SalesState>(
            builder: (context, salesState) {
              final loading = (cashierState.loading &&
                      cashierState.shifts.isEmpty) ||
                  (salesState.loading && salesState.sales.isEmpty);
              return AsyncBody(
                loading: loading,
                error: salesState.error ?? cashierState.error,
                onRetry: () {
                  context.read<SalesCubit>().load();
                  context.read<CashierCubit>().load();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                  children: [
                    SoftCard(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: open == null
                          ? Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Смена не открыта',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                FilledButton(
                                  onPressed: _openShiftDialog,
                                  child: const Text('Открыть'),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const StatusChip(
                                      label: 'Открыта',
                                      tone: StatusTone.success,
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => _closeShift(open),
                                      child: const Text('Закрыть'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'В кассе: ${formatRub(open.openingCash + open.cashSales - open.cashRefunds)}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Продажи нал. ${formatRub(open.cashSales)}'
                                  ' · возвраты ${formatRub(open.cashRefunds)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'Продажи',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (salesState.sales.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Пока нет продаж'),
                      )
                    else
                      for (final sale in salesState.sales)
                        EntityListTile(
                          title: Text(formatRub(sale.total)),
                          subtitle: Text(_lineSummary(sale)),
                          trailing: IconButton(
                            icon: const Icon(Icons.undo),
                            tooltip: 'Возврат',
                            onPressed: () =>
                                _openRefund(sale, open?.id),
                          ),
                        ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
