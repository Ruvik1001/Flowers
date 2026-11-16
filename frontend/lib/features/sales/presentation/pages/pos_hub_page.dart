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
import 'package:flowers/features/cashier/presentation/pages/shift_detail_page.dart';
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
  Shift? _lastClosed;

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

  List<Shift> _closedShifts(CashierState state) {
    final closed = state.shifts.where((s) => !s.isOpen).toList();
    closed.sort((a, b) => (b.closedAt ?? '').compareTo(a.closedAt ?? ''));
    return closed;
  }

  Map<int, List<Shift>> _closedByYear(List<Shift> closed) {
    final map = <int, List<Shift>>{};
    for (final s in closed) {
      final year = DateTime.tryParse(s.closedAt ?? '')?.toLocal().year ??
          DateTime.tryParse(s.openedAt ?? '')?.toLocal().year ??
          DateTime.now().year;
      map.putIfAbsent(year, () => []).add(s);
    }
    return map;
  }

  double _shiftRevenue(Shift shift, List<Sale> sales) {
    return sales
        .where((s) => s.shiftId == shift.id)
        .fold<double>(0, (sum, s) => sum + s.total);
  }

  List<Sale> _salesForShift(Shift? shift, List<Sale> sales) {
    if (shift == null) return const [];
    return sales.where((s) => s.shiftId == shift.id).toList();
  }

  String _lineSummary(Sale sale) {
    if (sale.lines.isEmpty) return 'Без позиций';
    return sale.lines.map((l) {
      final name = _productNames[l.productId] ?? 'Товар';
      return '$name × ${l.quantity}';
    }).join(', ');
  }

  String _formatShiftDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    return '$dd.$mm.$yyyy';
  }

  Future<void> _openShiftDetail(Shift shift, List<Sale> allSales) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShiftDetailPage(
          shift: shift,
          sales: _salesForShift(shift, allSales),
          productNames: _productNames,
        ),
      ),
    );
  }

  Future<void> _openSale(Shift? openShift) async {
    if (openShift == null) {
      AppMessage.showError(context, 'Сначала откройте смену');
      return;
    }
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
            decoration: const InputDecoration(
              labelText: 'Наличные в кассе при открытии',
            ),
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
      if (mounted) {
        setState(() => _lastClosed = null);
        AppMessage.showSuccess(context, 'Смена открыта');
      }
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, cashier.state.error ?? 'Ошибка');
      }
    }
  }

  Future<void> _movement(Shift shift, {required bool deposit}) async {
    final ctrl = TextEditingController();
    final title = deposit ? 'Внос наличных' : 'Самоинкассация';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: AppDialogScrollBody(
          child: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: deposit ? 'Сумма вноса' : 'Сумма изъятия',
              suffixText: '₽',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(deposit ? 'Внести' : 'Изъять'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      AppMessage.showError(context, 'Укажите сумму больше 0');
      return;
    }
    final cashier = context.read<CashierCubit>();
    try {
      await cashier.movement(
        shiftId: shift.id,
        kind: deposit ? 'deposit' : 'collection',
        amount: amount,
      );
      if (mounted) {
        AppMessage.showSuccess(
          context,
          deposit ? 'Внос ${formatRub(amount)}' : 'Изъято ${formatRub(amount)}',
        );
      }
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, cashier.state.error ?? 'Ошибка');
      }
    }
  }

  Future<void> _closeShift(Shift shift) async {
    final expected = shift.inDrawer;
    final ctrl = TextEditingController(text: expected.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Закрыть смену'),
        content: AppDialogScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ожидается в кассе: ${formatRub(expected)}'),
              const SizedBox(height: 8),
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
      final closed = await cashier.closeShift(
        shiftId: shift.id,
        actualCash: double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0,
      );
      if (mounted) {
        setState(() => _lastClosed = closed);
        AppMessage.showSuccess(context, 'Смена закрыта');
      }
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, cashier.state.error ?? 'Ошибка');
      }
    }
  }

  Widget _metric(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ),
          Text(
            formatRub(value),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
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
          final closed = _closedShifts(cashierState);
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
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Смена не открыта',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Откройте смену, чтобы принимать наличные и вести кассу.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _openShiftDialog,
                                  child: const Text('Открыть смену'),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const StatusChip(
                                      label: 'Смена открыта',
                                      tone: StatusTone.success,
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => _closeShift(open),
                                      child: const Text('Закрыть'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'В кассе: ${formatRub(open.inDrawer)}',
                                  style:
                                      Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 10),
                                _metric('Открытие', open.openingCash),
                                _metric('Продажи нал.', open.cashSales),
                                _metric('Возвраты', open.cashRefunds),
                                _metric('Вносы', open.cashIn),
                                _metric('Самоинкассация', open.cashOut),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _movement(open, deposit: true),
                                        child: const Text('Внос'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _movement(open, deposit: false),
                                        child: const Text('Самоинкассация'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    if (_lastClosed != null)
                      SoftCard(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Итог закрытой смены',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _metric(
                              'Ожидалось',
                              _lastClosed!.expectedCash ??
                                  _lastClosed!.inDrawer,
                            ),
                            _metric(
                              'Факт',
                              _lastClosed!.actualCash ?? 0,
                            ),
                            _metric(
                              'Расхождение',
                              _lastClosed!.discrepancy ?? 0,
                            ),
                          ],
                        ),
                      ),
                    if (closed.isNotEmpty) ...[
                      ...() {
                        final byYear = _closedByYear(closed);
                        final years = byYear.keys.toList()
                          ..sort((a, b) => b.compareTo(a));
                        return [
                          for (final year in years) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'Смены $year года',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            for (final s in byYear[year] ?? const <Shift>[])
                              EntityListTile(
                                onTap: () =>
                                    _openShiftDetail(s, salesState.sales),
                                title: Text(
                                  '${_formatShiftDate(s.closedAt)} · Закрыта'
                                  ' · выручка ${formatRub(_shiftRevenue(s, salesState.sales))}',
                                ),
                                subtitle: Text(
                                  'Ожид. ${formatRub(s.expectedCash ?? s.inDrawer)}'
                                  ' · факт ${formatRub(s.actualCash ?? 0)}'
                                  ' · Δ ${formatRub(s.discrepancy ?? 0)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                          ],
                        ];
                      }(),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        open == null
                            ? 'Продажи открытой смены'
                            : 'Продажи текущей смены',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (open == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Откройте смену, чтобы видеть её продажи. '
                          'Закрытые смены — в списке выше.',
                        ),
                      )
                    else if (_salesForShift(open, salesState.sales).isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Пока нет продаж'),
                      )
                    else
                      for (final sale
                          in _salesForShift(open, salesState.sales))
                        EntityListTile(
                          title: Text(formatRub(sale.total)),
                          subtitle: Text(_lineSummary(sale)),
                          trailing: IconButton(
                            icon: const Icon(Icons.undo),
                            tooltip: 'Возврат',
                            onPressed: () => _openRefund(sale, open.id),
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
