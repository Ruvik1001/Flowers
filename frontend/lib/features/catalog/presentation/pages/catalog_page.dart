import 'package:flowers/app/di.dart';
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
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';
import 'package:flowers/features/catalog/domain/entities/recipe_item.dart';
import 'package:flowers/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:flowers/features/catalog/presentation/cubit/catalog_state.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CatalogCubit(Di.I.catalog)..load(),
      child: const _CatalogView(),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        title: const Text('Каталог'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Товары'),
            Tab(text: 'Рецепты'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab-catalog',
          onPressed: () async {
            final choice = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.local_florist),
                      title: const Text('Товар'),
                      onTap: () => Navigator.pop(ctx, 'product'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: const Text('Рецепт'),
                      onTap: () => Navigator.pop(ctx, 'recipe'),
                    ),
                  ],
                ),
              ),
            );
            if (!context.mounted || choice == null) return;
            if (choice == 'product') {
              await _showCreateProductDialog(context);
            } else {
              await _showCreateRecipeDialog(context);
            }
          },
          child: const Icon(Icons.add),
        ),
        body: BlocBuilder<CatalogCubit, CatalogState>(
          builder: (context, state) {
            return AsyncBody(
              loading: state.loading &&
                  state.products.isEmpty &&
                  state.recipes.isEmpty,
              error: state.error,
              onRetry: () => context.read<CatalogCubit>().load(),
              child: TabBarView(
                children: [
                  _ProductsTab(products: state.products),
                  _RecipesTab(
                    recipes: state.recipes,
                    products: state.products,
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

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет товаров',
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return EntityListTile(
          title: Text(product.name),
          subtitle: Text(
            '${Labels.productKind(product.kind)} · ${formatRub(product.sellPrice)}',
          ),
          trailing: product.archived
              ? const StatusChip(label: 'Архив', tone: StatusTone.neutral)
              : IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'В архив',
                  onPressed: () async {
                    try {
                      await context
                          .read<CatalogCubit>()
                          .archiveProduct(product.id);
                      if (context.mounted) {
                        AppMessage.showSuccess(context, 'Товар в архиве');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppMessage.showError(context, 'Не удалось архивировать');
                      }
                    }
                  },
                ),
        );
      },
    );
  }
}

class _RecipesTab extends StatelessWidget {
  const _RecipesTab({required this.recipes, required this.products});

  final List<Recipe> recipes;
  final List<Product> products;

  String _bouquetName(String id) =>
      products.where((p) => p.id == id).firstOrNull?.name ?? 'Букет';

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет рецептов',
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return EntityListTile(
          title: Text(_bouquetName(recipe.bouquetId)),
          subtitle: Text('Позиций: ${recipe.items.length}'),
          trailing: recipe.archived
              ? const StatusChip(label: 'Архив', tone: StatusTone.neutral)
              : IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'В архив',
                  onPressed: () async {
                    try {
                      await context
                          .read<CatalogCubit>()
                          .archiveRecipe(recipe.id);
                      if (context.mounted) {
                        AppMessage.showSuccess(context, 'Рецепт в архиве');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppMessage.showError(context, 'Не удалось архивировать');
                      }
                    }
                  },
                ),
        );
      },
    );
  }
}

Future<void> _showCreateProductDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  var kind = 'flower';
  final cubit = context.read<CatalogCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новый товар'),
            content: AppDialogScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: kind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const [
                      DropdownMenuItem(value: 'flower', child: Text('Цветок')),
                      DropdownMenuItem(
                        value: 'material',
                        child: Text('Материал'),
                      ),
                      DropdownMenuItem(value: 'bouquet', child: Text('Букет')),
                    ],
                    onChanged: (v) => setState(() => kind = v ?? kind),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Цена'),
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
  final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  try {
    await cubit.createProduct(
      name: nameCtrl.text.trim(),
      kind: kind,
      sellPrice: price,
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Товар создан');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка создания товара');
    }
  }
}

Future<void> _showCreateRecipeDialog(BuildContext context) async {
  final cubit = context.read<CatalogCubit>();
  final products = cubit.state.products;
  String? bouquetId;
  String? componentId;
  final qtyCtrl = TextEditingController(text: '1');

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новый рецепт'),
            content: AppDialogScrollBody(
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
                  const SizedBox(height: 8),
                  ProductDropdown(
                    products: products,
                    value: componentId,
                    excludeKinds: const {'bouquet'},
                    label: 'Компонент',
                    onChanged: (v) => setState(() => componentId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                child: const Text('Создать'),
              ),
            ],
          );
        },
      );
    },
  );

  if (ok != true) return;
  if (bouquetId == null || componentId == null) {
    if (context.mounted) {
      AppMessage.showError(context, 'Выберите букет и компонент');
    }
    return;
  }
  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  try {
    await cubit.createRecipe(
      bouquetId: bouquetId!,
      items: [RecipeItem(productId: componentId!, quantity: qty)],
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Рецепт создан');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка создания рецепта');
    }
  }
}
