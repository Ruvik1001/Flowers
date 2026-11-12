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
import 'package:flowers/core/widgets/entity_dropdowns.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
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
      create: (_) => ProcurementCubit(Di.I.procurement)..load(),
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
      child: AppPageScaffold(
        title: const Text('Закупки'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Поставщики'),
            Tab(text: 'Поставки'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab-procurement',
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
                  _SuppliesTab(
                    supplies: state.supplies,
                    suppliers: state.suppliers,
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
  const _SuppliersTab({required this.suppliers});

  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет поставщиков',
        emptyIcon: Icons.store_outlined,
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
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

  void _toggleExpanded(String supplyId) {
    setState(() {
      if (_expandedIds.contains(supplyId)) {
        _expandedIds.remove(supplyId);
      } else {
        _expandedIds.add(supplyId);
      }
    });
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
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _collapsedSummary(Supply supply) {
    final count = supply.lines.length;
    if (count == 0) return 'Без позиций';
    final names = supply.lines
        .take(2)
        .map((line) => _productName(line.productId))
        .join(', ');
    if (count <= 2) return '$count поз.: $names';
    return '$count поз.: $names и ещё ${count - 2}';
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
        return SoftCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      onTap: () => _toggleExpanded(supply.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.expand_more,
                                color: AppColors.leaf,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
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
                                  if (!expanded) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _collapsedSummary(supply),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Принять линию',
                    onPressed: () => _showAcceptDialog(context, supply),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Состав поставки',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.leafDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (supply.lines.isEmpty)
                        Text(
                          'Без позиций',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        )
                      else
                        for (final line in supply.lines) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _productName(line.productId),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_qtyLabel(line.ordered)} шт · ${formatRub(line.unitCost)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Принято: ${_qtyLabel(line.accepted)} из ${_qtyLabel(line.ordered)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: line.accepted >= line.ordered
                                    ? AppColors.success
                                    : AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
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

Future<void> _showCreateSupplyDialog(BuildContext context) async {
  final cubit = context.read<ProcurementCubit>();
  final suppliers = cubit.state.suppliers;
  if (suppliers.isEmpty) {
    AppMessage.showError(context, 'Сначала создайте поставщика');
    return;
  }

  List<Product> products;
  try {
    products = await Di.I.catalog.listProducts();
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Не удалось загрузить товары');
    }
    return;
  }
  if (!context.mounted) return;

  String? supplierId;
  String? productId;
  final qtyCtrl = TextEditingController(text: '1');
  final costCtrl = TextEditingController(text: '0');

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новая поставка'),
            content: AppDialogScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SupplierDropdown(
                    suppliers: suppliers,
                    value: supplierId,
                    onChanged: (v) => setState(() => supplierId = v),
                  ),
                  const SizedBox(height: 8),
                  ProductDropdown(
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
                  TextField(
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(labelText: 'Себестоимость'),
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
          );
        },
      );
    },
  );
  if (ok != true) return;
  if (supplierId == null || productId == null) {
    if (context.mounted) {
      AppMessage.showError(context, 'Выберите поставщика и товар');
    }
    return;
  }
  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  try {
    await cubit.createSupply(
      supplierId: supplierId!,
      lines: [
        SupplyLine(
          productId: productId!,
          quantity: qty,
          ordered: qty,
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
  if (supply.lines.isEmpty) {
    AppMessage.showError(context, 'Нет линий для приёмки');
    return;
  }

  List<Product> products;
  try {
    products = await Di.I.catalog.listProducts(includeArchived: true);
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Не удалось загрузить товары');
    }
    return;
  }
  if (!context.mounted) return;

  final productIds = supply.lines.map((l) => l.productId).toList();
  String? productId = productIds.first;
  final qtyCtrl = TextEditingController(text: '1');
  final cubit = context.read<ProcurementCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Принять линию'),
            content: AppDialogScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SupplyLineProductDropdown(
                    productIds: productIds,
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
                child: const Text('Принять'),
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
  try {
    await cubit.acceptLine(
      supplyId: supply.id,
      productId: productId!,
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
