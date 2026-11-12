import 'package:flowers/app/di.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_dialog.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/procurement/domain/entities/supplier.dart';
import 'package:flowers/features/procurement/domain/entities/supply.dart';
import 'package:flowers/features/procurement/presentation/cubit/procurement_cubit.dart';
import 'package:flowers/features/procurement/presentation/cubit/procurement_state.dart';
import 'package:flowers/features/procurement/presentation/pages/accept_supply_page.dart';
import 'package:flowers/features/procurement/presentation/pages/create_supply_page.dart';

enum _SupplyStatus { open, partial, complete }

_SupplyStatus _statusOf(Supply supply) {
  if (supply.lines.isEmpty) return _SupplyStatus.open;
  final allDone = supply.lines.every((l) => l.accepted >= l.ordered);
  if (allDone) return _SupplyStatus.complete;
  final any = supply.lines.any((l) => l.accepted > 0);
  return any ? _SupplyStatus.partial : _SupplyStatus.open;
}

class ProcurementPage extends StatelessWidget {
  const ProcurementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProcurementCubit(Di.I.procurement)..load(),
      child: const _ProcurementView(),
    );
  }
}

class _ProcurementView extends StatelessWidget {
  const _ProcurementView();

  Future<void> _openCreateSupply(BuildContext context) async {
    final cubit = context.read<ProcurementCubit>();
    if (cubit.state.suppliers.isEmpty) {
      AppMessage.showError(context, 'Сначала создайте поставщика');
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: CreateSupplyPage(suppliers: cubit.state.suppliers),
        ),
      ),
    );
  }

  Future<void> _showCreateSupplier(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cubit = context.read<ProcurementCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый поставщик'),
        content: AppDialogScrollBody(
          child: Column(
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        title: const Text('Закупки'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Поставки'),
            Tab(text: 'Поставщики'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-procurement',
          onPressed: () => _openCreateSupply(context),
          icon: const Icon(Icons.add),
          label: const Text('Поставка'),
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
                  _SuppliesTab(
                    supplies: state.supplies,
                    suppliers: state.suppliers,
                  ),
                  _SuppliersTab(
                    suppliers: state.suppliers,
                    onAdd: () => _showCreateSupplier(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab({required this.suppliers, required this.onAdd});

  final List<Supplier> suppliers;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.store),
            label: const Text('Новый поставщик'),
          ),
        ),
        Expanded(
          child: suppliers.isEmpty
              ? const AsyncBody(
                  loading: false,
                  isEmpty: true,
                  emptyMessage: 'Нет поставщиков',
                  emptyIcon: Icons.store_outlined,
                  child: SizedBox.shrink(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final s = suppliers[index];
                    final phone =
                        s.phone?.isNotEmpty == true ? s.phone! : 'без телефона';
                    return EntityListTile(
                      title: Text(s.name),
                      subtitle: Text(phone),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SuppliesTab extends StatefulWidget {
  const _SuppliesTab({
    required this.supplies,
    required this.suppliers,
  });

  final List<Supply> supplies;
  final List<Supplier> suppliers;

  @override
  State<_SuppliesTab> createState() => _SuppliesTabState();
}

class _SuppliesTabState extends State<_SuppliesTab> {
  Map<String, String> _productNames = {};
  final Set<String> _expandedIds = {};

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

  String _supplierName(String id) =>
      widget.suppliers.where((s) => s.id == id).firstOrNull?.name ??
      'Поставщик';

  String _productName(String id) {
    final name = _productNames[id];
    if (name != null && name.isNotEmpty) return name;
    if (id.isEmpty) return 'Неизвестный товар';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return Labels.orDash(null);
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

  String _qtyLabel(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Future<void> _openAccept(Supply supply) async {
    final cubit = context.read<ProcurementCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: AcceptSupplyPage(supply: supply),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.supplies.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет поставок',
        emptyIcon: Icons.local_shipping_outlined,
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: widget.supplies.length,
      itemBuilder: (context, index) {
        final supply = widget.supplies[index];
        final expanded = _expandedIds.contains(supply.id);
        final status = _statusOf(supply);
        final acceptedSum =
            supply.lines.fold<double>(0, (s, l) => s + l.accepted);
        final orderedSum =
            supply.lines.fold<double>(0, (s, l) => s + l.ordered);

        return SoftCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (expanded) {
                            _expandedIds.remove(supply.id);
                          } else {
                            _expandedIds.add(supply.id);
                          }
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _supplierName(supply.supplierId),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(supply.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusChip(
                                label: switch (status) {
                                  _SupplyStatus.open => 'Открыта',
                                  _SupplyStatus.partial => 'Частично',
                                  _SupplyStatus.complete => 'Принята',
                                },
                                tone: switch (status) {
                                  _SupplyStatus.open => StatusTone.neutral,
                                  _SupplyStatus.partial => StatusTone.warning,
                                  _SupplyStatus.complete => StatusTone.success,
                                },
                              ),
                              Text(
                                'Принято ${_qtyLabel(acceptedSum)} / ${_qtyLabel(orderedSum)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (status != _SupplyStatus.complete)
                    FilledButton(
                      onPressed: () => _openAccept(supply),
                      child: const Text('Принять'),
                    ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Text(
                  'Состав',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.leafDark,
                  ),
                ),
                const SizedBox(height: 6),
                for (final line in supply.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _productName(line.productId),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${_qtyLabel(line.accepted)}/${_qtyLabel(line.ordered)} · ${formatRub(line.unitCost)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
