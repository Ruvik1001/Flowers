import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_state.dart';
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
    return AppPageScaffold(
      title: const Text('Касса'),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-cashier',
        onPressed: () => _showOpenDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<CashierCubit, CashierState>(
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading && state.shifts.isEmpty,
            error: state.error,
            isEmpty: state.shifts.isEmpty,
            emptyMessage: 'Нет смен',
            emptyIcon: Icons.point_of_sale_outlined,
            onRetry: () => context.read<CashierCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: state.shifts.length,
              itemBuilder: (context, index) {
                final shift = state.shifts[index];
                final discrepancy = shift.discrepancy != null
                    ? ' · Δ ${formatRub(shift.discrepancy!)}'
                    : '';
                return EntityListTile(
                  title: Text(
                    shift.isOpen ? 'Смена открыта' : 'Смена закрыта',
                  ),
                  subtitle: Text(
                    'Открытие: ${formatRub(shift.openingCash)}'
                    '${shift.expectedCash != null ? ' · Ожидается: ${formatRub(shift.expectedCash!)}' : ''}'
                    '$discrepancy\n'
                    '${Labels.orDash(shift.openedAt)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusChip(
                        label: shift.isOpen ? 'Открыта' : 'Закрыта',
                        tone: shift.isOpen
                            ? StatusTone.success
                            : StatusTone.neutral,
                      ),
                      if (shift.isOpen)
                        PopupMenuButton<String>(
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
                        ),
                    ],
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

Future<void> _showOpenDialog(BuildContext context) async {
  final auth = context.read<AuthCubit>().state;
  if (auth is! Authenticated) {
    AppMessage.showError(context, 'Требуется авторизация');
    return;
  }
  final user = auth.user;
  final cashCtrl = TextEditingController(text: '0');
  final cubit = context.read<CashierCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Открыть смену'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Кассир: ${user.email}'),
          ),
          const SizedBox(height: 12),
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
      cashierId: user.id,
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
