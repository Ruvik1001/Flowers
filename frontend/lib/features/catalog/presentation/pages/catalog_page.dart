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
import 'package:flowers/features/catalog/domain/entities/category.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';
import 'package:flowers/features/catalog/domain/entities/recipe_item.dart';
import 'package:flowers/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:flowers/features/catalog/presentation/cubit/catalog_state.dart';
import 'package:flowers/features/catalog/presentation/pages/product_editor_page.dart';

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

class _CatalogView extends StatefulWidget {
  const _CatalogView();

  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<_CatalogView> {
  String? _kindFilter;
  String? _categoryFilter;

  Future<void> _openProductEditor({Product? product}) async {
    final cubit = context.read<CatalogCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ProductEditorPage(
            product: product,
            categories: cubit.state.categories,
          ),
        ),
      ),
    );
  }

  Future<void> _createCategory() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория'),
        content: AppDialogScrollBody(
          child: TextField(
            controller: nameCtrl,
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
    final cubit = context.read<CatalogCubit>();
    try {
      await cubit.createCategory(name: nameCtrl.text.trim());
      if (mounted) AppMessage.showSuccess(context, 'Категория создана');
    } catch (_) {
      if (mounted) {
        AppMessage.showError(context, cubit.state.error ?? 'Ошибка');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppPageScaffold(
        title: const Text('Каталог'),
        actions: [
          BlocBuilder<CatalogCubit, CatalogState>(
            builder: (context, state) {
              return IconButton(
                tooltip: state.includeArchived
                    ? 'Скрыть архив'
                    : 'Показать архив',
                onPressed: () => context
                    .read<CatalogCubit>()
                    .load(includeArchived: !state.includeArchived),
                icon: Icon(
                  state.includeArchived
                      ? Icons.unarchive_outlined
                      : Icons.inventory_2_outlined,
                ),
              );
            },
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Товары'),
            Tab(text: 'Категории'),
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
                      leading: const Icon(Icons.category_outlined),
                      title: const Text('Категория'),
                      onTap: () => Navigator.pop(ctx, 'category'),
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
            if (!mounted || choice == null) return;
            if (choice == 'product') {
              await _openProductEditor();
            } else if (choice == 'category') {
              await _createCategory();
            } else {
              await _showCreateRecipeDialog(context);
            }
          },
          child: const Icon(Icons.add),
        ),
        body: BlocBuilder<CatalogCubit, CatalogState>(
          builder: (context, state) {
            final products = state.products.where((p) {
              if (_kindFilter != null && p.kind != _kindFilter) return false;
              if (_categoryFilter != null && p.categoryId != _categoryFilter) {
                return false;
              }
              return true;
            }).toList();
            return AsyncBody(
              loading: state.loading &&
                  state.products.isEmpty &&
                  state.categories.isEmpty,
              error: state.error,
              onRetry: () => context.read<CatalogCubit>().load(),
              child: TabBarView(
                children: [
                  _ProductsTab(
                    products: products,
                    categories: state.categories,
                    kindFilter: _kindFilter,
                    categoryFilter: _categoryFilter,
                    onKindFilter: (v) => setState(() => _kindFilter = v),
                    onCategoryFilter: (v) =>
                        setState(() => _categoryFilter = v),
                    onEdit: (p) => _openProductEditor(product: p),
                  ),
                  _CategoriesTab(categories: state.categories),
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
  const _ProductsTab({
    required this.products,
    required this.categories,
    required this.kindFilter,
    required this.categoryFilter,
    required this.onKindFilter,
    required this.onCategoryFilter,
    required this.onEdit,
  });

  final List<Product> products;
  final List<Category> categories;
  final String? kindFilter;
  final String? categoryFilter;
  final ValueChanged<String?> onKindFilter;
  final ValueChanged<String?> onCategoryFilter;
  final ValueChanged<Product> onEdit;

  String _categoryName(String? id) {
    if (id == null || id.isEmpty) return 'Без категории';
    return categories.where((c) => c.id == id).firstOrNull?.name ?? 'Категория';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: kindFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Тип'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все')),
                    for (final k in const ['flower', 'material', 'bouquet'])
                      DropdownMenuItem(
                        value: k,
                        child: Text(Labels.productKind(k)),
                      ),
                  ],
                  onChanged: onKindFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: categoryFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Категория'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все')),
                    for (final c in categories.where((c) => !c.archived))
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: onCategoryFilter,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const AsyncBody(
                  loading: false,
                  isEmpty: true,
                  emptyMessage: 'Нет товаров',
                  child: SizedBox.shrink(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 88),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return EntityListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        '${Labels.productKind(product.kind)} · '
                        '${_categoryName(product.categoryId)} · '
                        '${formatRub(product.sellPrice)}',
                      ),
                      onTap: product.archived
                          ? null
                          : () => onEdit(product),
                      trailing: product.archived
                          ? TextButton(
                              onPressed: () async {
                                final cubit = context.read<CatalogCubit>();
                                try {
                                  await cubit.unarchiveProduct(product.id);
                                  if (context.mounted) {
                                    AppMessage.showSuccess(
                                      context,
                                      'Товар восстановлен',
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    AppMessage.showError(
                                      context,
                                      cubit.state.error ?? 'Ошибка',
                                    );
                                  }
                                }
                              },
                              child: const Text('Восстановить'),
                            )
                          : IconButton(
                              icon: const Icon(Icons.archive_outlined),
                              tooltip: 'В архив',
                              onPressed: () async {
                                final cubit = context.read<CatalogCubit>();
                                try {
                                  await cubit.archiveProduct(product.id);
                                  if (context.mounted) {
                                    AppMessage.showSuccess(
                                      context,
                                      'Товар в архиве',
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    AppMessage.showError(
                                      context,
                                      'Не удалось архивировать',
                                    );
                                  }
                                }
                              },
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const AsyncBody(
        loading: false,
        isEmpty: true,
        emptyMessage: 'Нет категорий',
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return EntityListTile(
          title: Text(category.name),
          trailing: category.archived
              ? TextButton(
                  onPressed: () async {
                    final cubit = context.read<CatalogCubit>();
                    try {
                      await cubit.unarchiveCategory(category.id);
                      if (context.mounted) {
                        AppMessage.showSuccess(context, 'Категория восстановлена');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppMessage.showError(
                          context,
                          cubit.state.error ?? 'Ошибка',
                        );
                      }
                    }
                  },
                  child: const Text('Восстановить'),
                )
              : IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () async {
                    final cubit = context.read<CatalogCubit>();
                    try {
                      await cubit.archiveCategory(category.id);
                      if (context.mounted) {
                        AppMessage.showSuccess(context, 'В архиве');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppMessage.showError(context, 'Ошибка');
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
        final comps = recipe.items.map((i) {
          final name =
              products.where((p) => p.id == i.productId).firstOrNull?.name ??
                  'Товар';
          return '$name × ${i.quantity}';
        }).join(', ');
        return EntityListTile(
          title: Text(_bouquetName(recipe.bouquetId)),
          subtitle: Text(comps.isEmpty ? 'Без состава' : comps),
          trailing: recipe.archived
              ? TextButton(
                  onPressed: () async {
                    final cubit = context.read<CatalogCubit>();
                    try {
                      await cubit.unarchiveRecipe(recipe.id);
                      if (context.mounted) {
                        AppMessage.showSuccess(context, 'Рецепт восстановлен');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppMessage.showError(context, 'Ошибка');
                      }
                    }
                  },
                  child: const Text('Восстановить'),
                )
              : IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () async {
                    final cubit = context.read<CatalogCubit>();
                    try {
                      await cubit.archiveRecipe(recipe.id);
                      if (context.mounted) {
                        AppMessage.showSuccess(context, 'Рецепт в архиве');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppMessage.showError(context, 'Ошибка');
                      }
                    }
                  },
                ),
        );
      },
    );
  }
}

Future<void> _showCreateRecipeDialog(BuildContext context) async {
  final cubit = context.read<CatalogCubit>();
  final products = cubit.state.products.where((p) => !p.archived).toList();
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
      AppMessage.showError(context, cubit.state.error ?? 'Ошибка создания рецепта');
    }
  }
}
