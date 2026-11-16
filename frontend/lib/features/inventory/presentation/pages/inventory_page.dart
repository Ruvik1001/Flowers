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
import 'package:flowers/core/widgets/qty_stepper.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/inventory/domain/entities/folder.dart';
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
            initialProductName: lot == null ? null : _name(lot.productId),
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

  Future<void> _createFolder() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая папка'),
        content: AppDialogScrollBody(
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Название'),
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
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await context.read<InventoryCubit>().createFolder(name: name);
      if (mounted) AppMessage.showSuccess(context, 'Папка создана');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, 'Не удалось создать папку');
      }
    }
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
        quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
        unitCost: double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0,
      );
      if (mounted) AppMessage.showSuccess(context, 'Партия создана');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, cubit.state.error ?? 'Ошибка');
      }
    }
  }

  Future<void> _editLot(Lot lot) async {
    var qty = lot.quantity;
    final costCtrl = TextEditingController(text: lot.unitCost.toString());
    final expiresCtrl = TextEditingController(text: lot.expiresOn ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_name(lot.productId)),
          content: AppDialogScrollBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QtyStepper(
                  label: 'Количество',
                  value: qty,
                  min: 0,
                  onChanged: (v) => setLocal(() => qty = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Себестоимость'),
                ),
                TextField(
                  controller: expiresCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Срок (YYYY-MM-DD)',
                  ),
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
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final expires = expiresCtrl.text.trim();
    try {
      await context.read<InventoryCubit>().updateLot(
            id: lot.id,
            quantity: qty,
            unitCost:
                double.tryParse(costCtrl.text.replaceAll(',', '.')) ??
                    lot.unitCost,
            expiresOn: expires.isEmpty ? null : expires,
            clearExpiresOn: expires.isEmpty,
          );
      if (mounted) AppMessage.showSuccess(context, 'Партия обновлена');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, 'Не удалось обновить партию');
      }
    }
  }

  Future<void> _moveLot(Lot lot, List<InventoryFolder> folders) async {
    final choice = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Переместить в папку')),
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: const Text('Без папки'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final f in folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.name),
                onTap: () => Navigator.pop(ctx, f.id),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      await context.read<InventoryCubit>().updateLot(
            id: lot.id,
            folderId: choice.isEmpty ? null : choice,
            clearFolder: choice.isEmpty,
          );
      if (mounted) AppMessage.showSuccess(context, 'Перемещено');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, 'Не удалось переместить');
      }
    }
  }

  Future<void> _deleteLot(Lot lot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить партию?'),
        content: Text(
          '«${_name(lot.productId)}» · ${lot.quantity} шт будет удалена со склада.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<InventoryCubit>().deleteLot(lot.id);
      if (mounted) AppMessage.showSuccess(context, 'Партия удалена');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, 'Не удалось удалить партию');
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
              if (v == 'folder') _createFolder();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'lot',
                child: Text('Новая партия'),
              ),
              PopupMenuItem(
                value: 'folder',
                child: Text('Новая папка'),
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
                    folders: state.folders,
                    productName: _name,
                    onWriteOff: (lot) => _openWriteOff(lot: lot),
                    onEdit: _editLot,
                    onMove: (lot) => _moveLot(lot, state.folders),
                    onDelete: _deleteLot,
                    onReorder: (ids) =>
                        context.read<InventoryCubit>().reorderLots(ids),
                    onArchiveFolder: (id) async {
                      try {
                        await context.read<InventoryCubit>().archiveFolder(id);
                        if (context.mounted) {
                          AppMessage.showSuccess(context, 'Папка удалена');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          AppMessage.showError(
                            context,
                            'Не удалось удалить папку',
                          );
                        }
                      }
                    },
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
    required this.folders,
    required this.productName,
    required this.onWriteOff,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onReorder,
    required this.onArchiveFolder,
  });

  final List<Lot> lots;
  final List<InventoryFolder> folders;
  final String Function(String) productName;
  final ValueChanged<Lot> onWriteOff;
  final ValueChanged<Lot> onEdit;
  final ValueChanged<Lot> onMove;
  final ValueChanged<Lot> onDelete;
  final Future<void> Function(List<String> orderedIds) onReorder;
  final ValueChanged<String> onArchiveFolder;

  List<Lot> _sorted(Iterable<Lot> items) {
    final list = items.toList();
    list.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return (a.receivedAt ?? '').compareTo(b.receivedAt ?? '');
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty && folders.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет партий',
        emptyIcon: Icons.inventory_2_outlined,
        child: SizedBox.shrink(),
      );
    }

    final unassigned = _sorted(lots.where((l) => l.folderId == null));
    final sections = <Widget>[
      for (final folder in folders)
        _FolderSection(
          folder: folder,
          lots: _sorted(lots.where((l) => l.folderId == folder.id)),
          productName: productName,
          onWriteOff: onWriteOff,
          onEdit: onEdit,
          onMove: onMove,
          onDelete: onDelete,
          onReorder: onReorder,
          onArchiveFolder: onArchiveFolder,
        ),
      if (unassigned.isNotEmpty)
        _FolderSection(
          folder: null,
          title: folders.isEmpty ? null : 'Без папки',
          lots: unassigned,
          productName: productName,
          onWriteOff: onWriteOff,
          onEdit: onEdit,
          onMove: onMove,
          onDelete: onDelete,
          onReorder: onReorder,
          onArchiveFolder: onArchiveFolder,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: sections,
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection({
    required this.lots,
    required this.productName,
    required this.onWriteOff,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onReorder,
    required this.onArchiveFolder,
    this.folder,
    this.title,
  });

  final InventoryFolder? folder;
  final String? title;
  final List<Lot> lots;
  final String Function(String) productName;
  final ValueChanged<Lot> onWriteOff;
  final ValueChanged<Lot> onEdit;
  final ValueChanged<Lot> onMove;
  final ValueChanged<Lot> onDelete;
  final Future<void> Function(List<String> orderedIds) onReorder;
  final ValueChanged<String> onArchiveFolder;

  @override
  Widget build(BuildContext context) {
    final header = title ?? folder?.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Icon(
                  folder == null ? Icons.inbox_outlined : Icons.folder_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    header,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (folder != null)
                  IconButton(
                    tooltip: 'Удалить папку',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onArchiveFolder(folder!.id),
                  ),
              ],
            ),
          ),
        if (lots.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Пусто'),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: lots.length,
            onReorder: (oldIndex, newIndex) async {
              final next = [...lots];
              if (newIndex > oldIndex) newIndex -= 1;
              final item = next.removeAt(oldIndex);
              next.insert(newIndex, item);
              await onReorder(next.map((e) => e.id).toList());
            },
            itemBuilder: (context, index) {
              final lot = lots[index];
              return _LotTile(
                key: ValueKey(lot.id),
                lot: lot,
                index: index,
                productName: productName(lot.productId),
                onWriteOff: () => onWriteOff(lot),
                onEdit: () => onEdit(lot),
                onMove: () => onMove(lot),
                onDelete: () => onDelete(lot),
              );
            },
          ),
      ],
    );
  }
}

class _LotTile extends StatelessWidget {
  const _LotTile({
    super.key,
    required this.lot,
    required this.index,
    required this.productName,
    required this.onWriteOff,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
  });

  final Lot lot;
  final int index;
  final String productName;
  final VoidCallback onWriteOff;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return EntityListTile(
      title: Text(productName),
      subtitle: Text(
        'Кол-во: ${lot.quantity} · ${formatRub(lot.unitCost)}\n'
        'Срок: ${Labels.orDash(lot.expiresOn)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_handle),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'move':
                  onMove();
                case 'writeoff':
                  onWriteOff();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Редактировать')),
              PopupMenuItem(value: 'move', child: Text('В папку')),
              PopupMenuItem(value: 'writeoff', child: Text('Списать')),
              PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ],
          ),
        ],
      ),
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
