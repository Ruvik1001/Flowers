import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/core/widgets/entity_dropdowns.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_cubit.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';

class AssemblyEditorPage extends StatefulWidget {
  const AssemblyEditorPage({super.key});

  @override
  State<AssemblyEditorPage> createState() => _AssemblyEditorPageState();
}

class _AssemblyEditorPageState extends State<AssemblyEditorPage> {
  var _loading = true;
  var _saving = false;
  List<Product> _products = const [];
  List<Recipe> _recipes = const [];

  String? _bouquetId;
  String? _recipeId;
  String? _pendingComponentId;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _componentQtyCtrl;
  var _kind = 'free';
  final _components = <AssemblyComponent>[];

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
    _componentQtyCtrl = TextEditingController(text: '1');
    _loadCatalog();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _componentQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final products = await Di.I.catalog.listProducts();
      final recipes = await Di.I.catalog.listRecipes();
      if (!mounted) return;
      setState(() {
        _products = products;
        _recipes = recipes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppMessage.showError(context, 'Не удалось загрузить каталог');
    }
  }

  String _productName(String id) =>
      _products.where((p) => p.id == id).firstOrNull?.name ?? 'Товар';

  Future<void> _save() async {
    if (_bouquetId == null || _bouquetId!.isEmpty) {
      AppMessage.showError(context, 'Выберите букет');
      return;
    }
    if (_components.isEmpty) {
      AppMessage.showError(context, 'Добавьте компоненты');
      return;
    }
    setState(() => _saving = true);
    final cubit = context.read<AssemblyCubit>();
    try {
      await cubit.create(
        bouquetProductId: _bouquetId!,
        quantity: double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0,
        kind: _kind,
        recipeId: _kind == 'recipe' ? _recipeId : null,
        components: List.of(_components),
      );
      if (!mounted) return;
      AppMessage.showSuccess(context, 'Сборка создана');
      Navigator.pop(context, true);
    } on AppFailure catch (e) {
      if (!mounted) return;
      AppMessage.showError(
        context,
        Labels.errorCode(e.code, e.message),
      );
    } catch (_) {
      if (!mounted) return;
      AppMessage.showError(context, cubit.state.error ?? 'Ошибка сборки');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: 'Новая сборка',
      actionLabel: 'Собрать',
      actionLoading: _saving,
      onAction: _saving || _loading ? null : _save,
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductDropdown(
                  products: _products,
                  value: _bouquetId,
                  kinds: const {'bouquet'},
                  label: 'Букет',
                  onChanged: (v) => setState(() => _bouquetId = v),
                ),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Количество'),
                ),
                DropdownButtonFormField<String>(
                  value: _kind,
                  isExpanded: true,
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
                      _kind = v ?? _kind;
                      if (_kind == 'recipe') {
                        _components.clear();
                      }
                    });
                  },
                ),
                if (_kind == 'recipe')
                  RecipeDropdown(
                    recipes: _recipes,
                    products: _products,
                    value: _recipeId,
                    onChanged: (v) {
                      setState(() {
                        _recipeId = v;
                        _components.clear();
                        final recipe =
                            _recipes.where((r) => r.id == v).firstOrNull;
                        if (recipe != null) {
                          _bouquetId = recipe.bouquetId;
                          _components.addAll(
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
                if (_kind == 'free') ...[
                  const SizedBox(height: 8),
                  ProductDropdown(
                    products: _products,
                    value: _pendingComponentId,
                    excludeKinds: const {'bouquet'},
                    label: 'Компонент',
                    validator: (_) => null,
                    onChanged: (v) =>
                        setState(() => _pendingComponentId = v),
                  ),
                  TextField(
                    controller: _componentQtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Кол-во компонента',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        if (_pendingComponentId == null) return;
                        final q = double.tryParse(
                              _componentQtyCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0;
                        setState(() {
                          _components.add(
                            AssemblyComponent(
                              productId: _pendingComponentId!,
                              quantity: q,
                            ),
                          );
                          _pendingComponentId = null;
                          _componentQtyCtrl.text = '1';
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить компонент'),
                    ),
                  ),
                ],
                if (_components.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Компоненты',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (var i = 0; i < _components.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_productName(_components[i].productId)),
                      subtitle: Text('× ${_components[i].quantity}'),
                      trailing: _kind == 'free'
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(
                                () => _components.removeAt(i),
                              ),
                            )
                          : null,
                    ),
                ],
              ],
            ),
    );
  }
}
