import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Каталог'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Товары'),
              Tab(text: 'Рецепты'),
            ],
          ),
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
                  _RecipesTab(recipes: state.recipes),
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
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text('${product.kind} · ${formatRub(product.sellPrice)}'),
          trailing: product.archived
              ? const Chip(label: Text('Архив'))
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
  const _RecipesTab({required this.recipes});

  final List<Recipe> recipes;

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
    return ListView.separated(
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return ListTile(
          title: Text('Букет ${recipe.bouquetId}'),
          subtitle: Text('Позиций: ${recipe.items.length}'),
          trailing: recipe.archived
              ? const Chip(label: Text('Архив'))
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
            content: SingleChildScrollView(
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
  final bouquetCtrl = TextEditingController();
  final productCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final cubit = context.read<CatalogCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Новый рецепт'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bouquetCtrl,
                decoration: const InputDecoration(labelText: 'ID букета'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: productCtrl,
                decoration: const InputDecoration(labelText: 'ID компонента'),
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

  if (ok != true) return;
  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  try {
    await cubit.createRecipe(
      bouquetId: bouquetCtrl.text.trim(),
      items: [
        RecipeItem(
          productId: productCtrl.text.trim(),
          quantity: qty,
        ),
      ],
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
