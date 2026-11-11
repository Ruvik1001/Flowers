import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';
import 'package:flowers/features/cashier/presentation/cubit/cashier_cubit.dart';
import 'package:flowers/features/cashier/presentation/cubit/cashier_state.dart';

class CashierPage extends StatelessWidget {
  const CashierPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CashierCubit(Di.I.cashier)..load(),
      child: const _CashierView(),
    );
  }
}

class _CashierView extends StatelessWidget {
  const _CashierView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Касса')),
      body: BlocBuilder<CashierCubit, CashierState>(
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading && state.shifts.isEmpty,
            error: state.error,
            isEmpty: state.shifts.isEmpty,
            emptyMessage: 'Нет смен',
            onRetry: () => context.read<CashierCubit>().load(),
            child: ListView.separated(
              itemCount: state.shifts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final shift = state.shifts[index];
                return ListTile(
                  title: Text('Смена ${shift.id}'),
                  subtitle: Text(
                    'Кассир: ${shift.cashierId}\n'
                    'Открытие: ${formatRub(shift.openingCash)} · '
                    '${shift.isOpen ? 'открыта' : 'закрыта'}'
                    '${shift.discrepancy != null ? ' · Δ ${formatRub(shift.discrepancy!)}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: shift.isOpen
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'cash') {
                              _showCashDialog(context, shift);
                            } else if (value == 'close') {
                              _showCloseDialog(context, shift);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'cash',
                              child: Text('Внести наличные'),
                            ),
                            PopupMenuItem(
                              value: 'close',
                              child: Text('Закрыть смену'),
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOpenDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _showOpenDialog(BuildContext context) async {
  final cashierCtrl = TextEditingController();
  final cashCtrl = TextEditingController(text: '0');
  final cubit = context.read<CashierCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Открыть смену'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: cashierCtrl,
            decoration: const InputDecoration(labelText: 'ID кассира'),
          ),
          TextField(
            controller: cashCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Наличные в кассе'),
          ),
        ],
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
  if (ok != true) return;
  try {
    await cubit.open(
      cashierId: cashierCtrl.text.trim(),
      openingCash: double.tryParse(cashCtrl.text.replaceAll(',', '.')) ?? 0,
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Смена открыта');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Не удалось открыть смену');
    }
  }
}

Future<void> _showCashDialog(BuildContext context, Shift shift) async {
  final amountCtrl = TextEditingController();
  var refund = false;
  final cubit = context.read<CashierCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Наличные'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Сумма'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Возврат'),
                  value: refund,
                  onChanged: (v) => setState(() => refund = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Записать'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ok != true) return;
  try {
    await cubit.cash(
      shiftId: shift.id,
      amount: double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0,
      refund: refund,
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Записано');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка записи');
    }
  }
}

Future<void> _showCloseDialog(BuildContext context, Shift shift) async {
  final actualCtrl = TextEditingController(
    text: (shift.expectedCash ?? shift.openingCash).toStringAsFixed(2),
  );
  final cubit = context.read<CashierCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Закрыть смену'),
      content: TextField(
        controller: actualCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Факт в кассе'),
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
  if (ok != true) return;
  try {
    await cubit.closeShift(
      shiftId: shift.id,
      actualCash: double.tryParse(actualCtrl.text.replaceAll(',', '.')) ?? 0,
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Смена закрыта');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка закрытия');
    }
  }
}
