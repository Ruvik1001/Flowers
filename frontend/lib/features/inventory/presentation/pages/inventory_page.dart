import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_dialog.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/product_picker_sheet.dart';
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/inventory/domain/entities/lot.dart';
import 'package:flowers/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:flowers/features/inventory/presentation/cubit/inventory_state.dart';
import 'package:flowers/features/inventory/presentation/pages/inventory_count_page.dart';
import 'package:flowers/features/inventory/presentation/pages/write_off_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InventoryCubit(Di.I.inventory)..load(),
      child: const _InventoryView(),
    );
  }
}

class _InventoryView extends StatefulWidget {
  const _InventoryView();

  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  Map<String, String> _productNames = {};
  List<Product> _products = const [];

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
        _products = products;
        _productNames = {for (final p in products) p.id: p.name};
      });
    } catch (_) {}
  }

  String _name(String productId) => _productNames[productId] ?? 'Товар';

  Future<void> _openWriteOff({Lot? lot}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<InventoryCubit>(),
          child: WriteOffPage(
            initialProductId: lot?.productId,
            initialProductName:
                lot == null ? null : _name(lot.productId),
            initialQuantity: lot?.quantity,
          ),
        ),
      ),
    );
  }

  Future<void> _openCount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<InventoryCubit>(),
          child: const InventoryCountPage(),
        ),
      ),
    );
  }

  Future<void> _createLot() async {
    final products = _products.isEmpty
        ? await Di.I.catalog.listProducts()
        : _products;
    if (!mounted) return;
    final picked = await showProductPickerSheet(
      context: context,
      products: products,
    );
    if (picked == null || !mounted) return;

    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Партия: ${picked.name}'),
        content: AppDialogScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
    if (ok != true || !mounted) return;
    final cubit = context.read<InventoryCubit>();
    try {
      await cubit.createLot(
            productId: picked.id,
            quantity:
                double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
            unitCost:
                double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0,
          );
      if (mounted) AppMessage.showSuccess(context, 'Партия создана');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(
          context,
          cubit.state.error ?? 'Ошибка',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        title: const Text('Склад'),
        actions: [
          IconButton(
            tooltip: 'Списание',
            onPressed: () => _openWriteOff(),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: 'Инвентаризация',
            onPressed: _openCount,
            icon: const Icon(Icons.fact_check_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'lot') _createLot();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'lot',
                child: Text('Новая партия'),
              ),
            ],
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Остатки'),
            Tab(text: 'Просрочка'),
          ],
        ),
        body: BlocConsumer<InventoryCubit, InventoryState>(
          listenWhen: (p, c) =>
              p.lastMessage != c.lastMessage && c.lastMessage != null,
          listener: (context, state) {
            if (state.lastMessage != null) {
              AppMessage.showSuccess(context, state.lastMessage!);
            }
          },
          builder: (context, state) {
            return AsyncBody(
              loading: state.loading && state.lots.isEmpty,
              error: state.error,
              onRetry: () => context.read<InventoryCubit>().load(),
              child: TabBarView(
                children: [
                  _LotsTab(
                    lots: state.lots,
                    productName: _name,
                    onWriteOff: (lot) => _openWriteOff(lot: lot),
                  ),
                  _ExpiredTab(
                    lots: state.expired,
                    productName: _name,
                    onWriteOff: (lot) => _openWriteOff(lot: lot),
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

class _LotsTab extends StatelessWidget {
  const _LotsTab({
    required this.lots,
    required this.productName,
    required this.onWriteOff,
  });

  final List<Lot> lots;
  final String Function(String) productName;
  final ValueChanged<Lot> onWriteOff;

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет партий',
        emptyIcon: Icons.inventory_2_outlined,
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: lots.length,
      itemBuilder: (context, index) {
        final lot = lots[index];
        return EntityListTile(
          title: Text(productName(lot.productId)),
          subtitle: Text(
            'Кол-во: ${lot.quantity} · ${formatRub(lot.unitCost)}\n'
            'Срок: ${Labels.orDash(lot.expiresOn)}',
          ),
          trailing: TextButton(
            onPressed: () => onWriteOff(lot),
            child: const Text('Списать'),
          ),
        );
      },
    );
  }
}

class _ExpiredTab extends StatelessWidget {
  const _ExpiredTab({
    required this.lots,
    required this.productName,
    required this.onWriteOff,
  });

  final List<Lot> lots;
  final String Function(String) productName;
  final ValueChanged<Lot> onWriteOff;

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет просроченных партий',
        emptyIcon: Icons.event_busy_outlined,
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: lots.length,
      itemBuilder: (context, index) {
        final lot = lots[index];
        return EntityListTile(
          title: Text(productName(lot.productId)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Кол-во: ${lot.quantity} · до ${Labels.orDash(lot.expiresOn)}',
              ),
              const SizedBox(height: 6),
              const StatusChip(
                label: 'Просрочено',
                tone: StatusTone.warning,
              ),
            ],
          ),
          trailing: FilledButton.tonal(
            onPressed: () => onWriteOff(lot),
            child: const Text('Списать'),
          ),
        );
      },
    );
  }
}
