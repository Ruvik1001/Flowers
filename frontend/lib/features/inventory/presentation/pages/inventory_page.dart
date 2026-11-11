import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_dropdowns.dart';
import 'package:flowers/core/widgets/photo_upload_field.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/inventory/domain/entities/lot.dart';
import 'package:flowers/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:flowers/features/inventory/presentation/cubit/inventory_state.dart';

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
        _productNames = {
          for (final p in products) p.id: p.name,
        };
      });
    } catch (_) {}
  }

  String _name(String productId) =>
      _productNames[productId] ?? 'Товар';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Склад'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Партии'),
              Tab(text: 'Просрочка'),
              Tab(text: 'Списание'),
              Tab(text: 'Инвентаризация'),
            ],
          ),
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
                  _LotsTab(lots: state.lots, productName: _name),
                  _ExpiredTab(lots: state.expired, productName: _name),
                  const _WriteOffForm(),
                  const _CountForm(),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateLotDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _LotsTab extends StatelessWidget {
  const _LotsTab({required this.lots, required this.productName});

  final List<Lot> lots;
  final String Function(String) productName;

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty) {
      return const Center(child: Text('Нет партий'));
    }
    return ListView.separated(
      itemCount: lots.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lot = lots[index];
        return ListTile(
          title: Text(productName(lot.productId)),
          subtitle: Text(
            'Кол-во: ${lot.quantity} · ${formatRub(lot.unitCost)}\n'
            'Срок: ${Labels.orDash(lot.expiresOn)}',
          ),
          isThreeLine: true,
        );
      },
    );
  }
}

class _ExpiredTab extends StatelessWidget {
  const _ExpiredTab({required this.lots, required this.productName});

  final List<Lot> lots;
  final String Function(String) productName;

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty) {
      return const Center(child: Text('Нет просроченных партий'));
    }
    return ListView.separated(
      itemCount: lots.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lot = lots[index];
        return ListTile(
          title: Text(productName(lot.productId)),
          subtitle: Text(
            'Кол-во: ${lot.quantity} · до ${Labels.orDash(lot.expiresOn)}',
          ),
        );
      },
    );
  }
}

class _WriteOffForm extends StatefulWidget {
  const _WriteOffForm();

  @override
  State<_WriteOffForm> createState() => _WriteOffFormState();
}

class _WriteOffFormState extends State<_WriteOffForm> {
  List<Product> _products = const [];
  String? _productId;
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  List<String> _photoIds = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await Di.I.catalog.listProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProductDropdown(
          products: _products,
          value: _productId,
          onChanged: (v) => setState(() => _productId = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Количество'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonCtrl,
          decoration: const InputDecoration(labelText: 'Причина'),
        ),
        const SizedBox(height: 8),
        PhotoUploadField(
          fileIds: _photoIds,
          onChanged: (ids) => setState(() => _photoIds = ids),
          minCount: 1,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (_productId == null || _productId!.isEmpty) {
              AppMessage.showError(context, 'Выберите товар');
              return;
            }
            if (_photoIds.isEmpty) {
              AppMessage.showError(context, 'Нужно приложить хотя бы 1 фото');
              return;
            }
            try {
              await context.read<InventoryCubit>().writeOff(
                    productId: _productId!,
                    quantity:
                        double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ??
                            0,
                    reason: _reasonCtrl.text.trim(),
                    photoIds: _photoIds,
                  );
            } catch (_) {
              if (context.mounted) {
                AppMessage.showError(context, 'Ошибка списания');
              }
            }
          },
          child: const Text('Списать'),
        ),
      ],
    );
  }
}

class _CountForm extends StatefulWidget {
  const _CountForm();

  @override
  State<_CountForm> createState() => _CountFormState();
}

class _CountFormState extends State<_CountForm> {
  List<Product> _products = const [];
  String? _productId;
  final _actualCtrl = TextEditingController();
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await Di.I.catalog.listProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  @override
  void dispose() {
    _actualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProductDropdown(
          products: _products,
          value: _productId,
          onChanged: (v) => setState(() => _productId = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _actualCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Факт'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (_productId == null || _productId!.isEmpty) {
              AppMessage.showError(context, 'Выберите товар');
              return;
            }
            try {
              await context.read<InventoryCubit>().inventoryCount(
                    productId: _productId!,
                    actual: double.tryParse(
                          _actualCtrl.text.replaceAll(',', '.'),
                        ) ??
                        0,
                  );
            } catch (_) {
              if (context.mounted) {
                AppMessage.showError(context, 'Ошибка инвентаризации');
              }
            }
          },
          child: const Text('Провести'),
        ),
      ],
    );
  }
}

Future<void> _showCreateLotDialog(BuildContext context) async {
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

  String? productId;
  final qtyCtrl = TextEditingController(text: '1');
  final costCtrl = TextEditingController(text: '0');
  final expiresCtrl = TextEditingController();
  final cubit = context.read<InventoryCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новая партия'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  TextField(
                    controller: expiresCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Срок',
                      hintText: Labels.dateHint,
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
                child: const Text('Создать'),
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
    await cubit.createLot(
      productId: productId!,
      quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
      unitCost: double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0,
      expiresOn: expiresCtrl.text.trim(),
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Партия создана');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка создания партии');
    }
  }
}
