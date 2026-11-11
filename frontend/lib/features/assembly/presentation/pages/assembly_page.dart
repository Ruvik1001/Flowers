import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_dropdowns.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_cubit.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_state.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';

class AssemblyPage extends StatelessWidget {
  const AssemblyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssemblyCubit(Di.I.assembly)..load(),
      child: const _AssemblyView(),
    );
  }
}

class _AssemblyView extends StatefulWidget {
  const _AssemblyView();

  @override
  State<_AssemblyView> createState() => _AssemblyViewState();
}

class _AssemblyViewState extends State<_AssemblyView> {
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

  String _bouquetName(String id) => _productNames[id] ?? 'Букет';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сборка')),
      body: BlocBuilder<AssemblyCubit, AssemblyState>(
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading && state.assemblies.isEmpty,
            error: state.error,
            isEmpty: state.assemblies.isEmpty,
            emptyMessage: 'Нет сборок',
            onRetry: () => context.read<AssemblyCubit>().load(),
            child: ListView.separated(
              itemCount: state.assemblies.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = state.assemblies[index];
                return ListTile(
                  title: Text(_bouquetName(item.bouquetProductId)),
                  subtitle: Text(
                    '${Labels.assemblyKind(item.kind)} × ${item.quantity} · '
                    '${formatRub(item.cost)}',
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _showCreateDialog(BuildContext context) async {
  List<Product> products;
  List<Recipe> recipes;
  try {
    products = await Di.I.catalog.listProducts();
    recipes = await Di.I.catalog.listRecipes();
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Не удалось загрузить каталог');
    }
    return;
  }
  if (!context.mounted) return;

  String? bouquetId;
  String? recipeId;
  String? pendingComponentId;
  final qtyCtrl = TextEditingController(text: '1');
  final componentQtyCtrl = TextEditingController(text: '1');
  var kind = 'free';
  final components = <AssemblyComponent>[];
  final cubit = context.read<AssemblyCubit>();

  String productName(String id) =>
      products.where((p) => p.id == id).firstOrNull?.name ?? 'Товар';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новая сборка'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProductDropdown(
                    products: products,
                    value: bouquetId,
                    kinds: const {'bouquet'},
                    label: 'Букет',
                    onChanged: (v) => setState(() => bouquetId = v),
                  ),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                  DropdownButtonFormField<String>(
                    value: kind,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: [
                      DropdownMenuItem(
                        value: 'free',
                        child: Text(Labels.assemblyKind('free')),
                      ),
                      DropdownMenuItem(
                        value: 'recipe',
                        child: Text(Labels.assemblyKind('recipe')),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        kind = v ?? kind;
                        if (kind == 'recipe') {
                          components.clear();
                        }
                      });
                    },
                  ),
                  if (kind == 'recipe')
                    RecipeDropdown(
                      recipes: recipes,
                      products: products,
                      value: recipeId,
                      onChanged: (v) {
                        setState(() {
                          recipeId = v;
                          components.clear();
                          final recipe =
                              recipes.where((r) => r.id == v).firstOrNull;
                          if (recipe != null) {
                            bouquetId = recipe.bouquetId;
                            components.addAll(
                              recipe.items.map(
                                (i) => AssemblyComponent(
                                  productId: i.productId,
                                  quantity: i.quantity,
                                ),
                              ),
                            );
                          }
                        });
                      },
                    ),
                  if (kind == 'free') ...[
                    const SizedBox(height: 8),
                    ProductDropdown(
                      products: products,
                      value: pendingComponentId,
                      excludeKinds: const {'bouquet'},
                      label: 'Компонент',
                      validator: (_) => null,
                      onChanged: (v) =>
                          setState(() => pendingComponentId = v),
                    ),
                    TextField(
                      controller: componentQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Кол-во компонента',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          if (pendingComponentId == null) return;
                          final q = double.tryParse(
                                componentQtyCtrl.text.replaceAll(',', '.'),
                              ) ??
                              0;
                          setState(() {
                            components.add(
                              AssemblyComponent(
                                productId: pendingComponentId!,
                                quantity: q,
                              ),
                            );
                            pendingComponentId = null;
                            componentQtyCtrl.text = '1';
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить компонент'),
                      ),
                    ),
                  ],
                  if (components.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Компоненты',
                        style: Theme.of(ctx).textTheme.labelLarge,
                      ),
                    ),
                    for (var i = 0; i < components.length; i++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(productName(components[i].productId)),
                        subtitle: Text('${components[i].quantity}'),
                        trailing: kind == 'free'
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                  () => components.removeAt(i),
                                ),
                              )
                            : null,
                      ),
                  ],
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
                child: const Text('Собрать'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ok != true) return;

  if (bouquetId == null || bouquetId!.isEmpty) {
    if (context.mounted) {
      AppMessage.showError(context, 'Выберите букет');
    }
    return;
  }
  if (components.isEmpty) {
    if (context.mounted) {
      AppMessage.showError(context, 'Добавьте компоненты');
    }
    return;
  }

  try {
    await cubit.create(
      bouquetProductId: bouquetId!,
      quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
      kind: kind,
      recipeId: kind == 'recipe' ? recipeId : null,
      components: List.of(components),
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Сборка создана');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка сборки');
    }
  }
}
