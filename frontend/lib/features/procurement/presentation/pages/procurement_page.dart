import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/features/procurement/domain/entities/supplier.dart';
import 'package:flowers/features/procurement/domain/entities/supply.dart';
import 'package:flowers/features/procurement/domain/entities/supply_line.dart';
import 'package:flowers/features/procurement/presentation/cubit/procurement_cubit.dart';
import 'package:flowers/features/procurement/presentation/cubit/procurement_state.dart';

class ProcurementPage extends StatelessWidget {
  const ProcurementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ProcurementCubit(Di.I.procurement)..load(),
      child: const _ProcurementView(),
    );
  }
}

class _ProcurementView extends StatelessWidget {
  const _ProcurementView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Закупки'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Поставщики'),
              Tab(text: 'Поставки'),
            ],
          ),
        ),
        body: BlocBuilder<ProcurementCubit, ProcurementState>(
          builder: (context, state) {
            return AsyncBody(
              loading: state.loading &&
                  state.suppliers.isEmpty &&
                  state.supplies.isEmpty,
              error: state.error,
              onRetry: () => context.read<ProcurementCubit>().load(),
              child: TabBarView(
                children: [
                  _SuppliersTab(suppliers: state.suppliers),
                  _SuppliesTab(supplies: state.supplies),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final choice = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.store),
                      title: const Text('Поставщик'),
                      onTap: () => Navigator.pop(ctx, 'supplier'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_shipping),
                      title: const Text('Поставка'),
                      onTap: () => Navigator.pop(ctx, 'supply'),
                    ),
                  ],
                ),
              ),
            );
            if (!context.mounted || choice == null) return;
            if (choice == 'supplier') {
              await _showCreateSupplierDialog(context);
            } else {
              await _showCreateSupplyDialog(context);
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab({required this.suppliers});

  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return const Center(child: Text('Нет поставщиков'));
    }
    return ListView.separated(
      itemCount: suppliers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = suppliers[index];
        return ListTile(
          title: Text(s.name),
          subtitle: Text(s.phone?.isNotEmpty == true ? s.phone! : s.id),
        );
      },
    );
  }
}

class _SuppliesTab extends StatelessWidget {
  const _SuppliesTab({required this.supplies});

  final List<Supply> supplies;

  @override
  Widget build(BuildContext context) {
    if (supplies.isEmpty) {
      return const Center(child: Text('Нет поставок'));
    }
    return ListView.separated(
      itemCount: supplies.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final supply = supplies[index];
        return ListTile(
          title: Text('Поставка ${supply.id}'),
          subtitle: Text(
            'Поставщик: ${supply.supplierId}\n'
            'Линий: ${supply.lines.length}',
          ),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Принять линию',
            onPressed: () => _showAcceptDialog(context, supply),
          ),
        );
      },
    );
  }
}

Future<void> _showCreateSupplierDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final cubit = context.read<ProcurementCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Новый поставщик'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(labelText: 'Телефон'),
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
          child: const Text('Создать'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await cubit.createSupplier(
      name: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Поставщик создан');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка создания поставщика');
    }
  }
}

Future<void> _showCreateSupplyDialog(BuildContext context) async {
  final supplierCtrl = TextEditingController();
  final productCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final costCtrl = TextEditingController(text: '0');
  final cubit = context.read<ProcurementCubit>();
  final suppliers = cubit.state.suppliers;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Новая поставка'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suppliers.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Поставщик'),
                items: suppliers
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) supplierCtrl.text = v;
                },
              )
            else
              TextField(
                controller: supplierCtrl,
                decoration: const InputDecoration(labelText: 'ID поставщика'),
              ),
            TextField(
              controller: productCtrl,
              decoration: const InputDecoration(labelText: 'ID товара'),
            ),
            TextField(
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Количество'),
            ),
            TextField(
              controller: costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Себестоимость'),
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
          child: const Text('Создать'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await cubit.createSupply(
      supplierId: supplierCtrl.text.trim(),
      lines: [
        SupplyLine(
          productId: productCtrl.text.trim(),
          quantity:
              double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
          ordered:
              double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
          unitCost:
              double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0,
          accepted: 0,
        ),
      ],
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Поставка создана');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка создания поставки');
    }
  }
}

Future<void> _showAcceptDialog(BuildContext context, Supply supply) async {
  final productCtrl = TextEditingController(
    text: supply.lines.isNotEmpty ? supply.lines.first.productId : '',
  );
  final qtyCtrl = TextEditingController(text: '1');
  final cubit = context.read<ProcurementCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Принять линию'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (supply.lines.isNotEmpty)
            DropdownButtonFormField<String>(
              value: productCtrl.text.isEmpty ? null : productCtrl.text,
              decoration: const InputDecoration(labelText: 'Товар'),
              items: supply.lines
                  .map(
                    (l) => DropdownMenuItem(
                      value: l.productId,
                      child: Text(
                        '${l.productId} (${l.accepted}/${l.ordered})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) productCtrl.text = v;
              },
            )
          else
            TextField(
              controller: productCtrl,
              decoration: const InputDecoration(labelText: 'ID товара'),
            ),
          TextField(
            controller: qtyCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Количество'),
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
          child: const Text('Принять'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await cubit.acceptLine(
      supplyId: supply.id,
      productId: productCtrl.text.trim(),
      quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Линия принята');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка приёмки');
    }
  }
}
