import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/features/catalog/domain/entities/category.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/presentation/cubit/catalog_cubit.dart';

class ProductEditorPage extends StatefulWidget {
  const ProductEditorPage({
    super.key,
    this.product,
    required this.categories,
  });

  final Product? product;
  final List<Category> categories;

  @override
  State<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _ProductEditorPageState extends State<ProductEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late String _kind;
  String? _categoryId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(
      text: p == null ? '' : p.sellPrice.toStringAsFixed(2),
    );
    _kind = p?.kind ?? 'flower';
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price =
        double.tryParse(_price.text.replaceAll(',', '.')) ?? -1;
    if (name.isEmpty) {
      AppMessage.showError(context, 'Укажите название');
      return;
    }
    if (price < 0) {
      AppMessage.showError(context, 'Укажите цену');
      return;
    }
    setState(() => _saving = true);
    final cubit = context.read<CatalogCubit>();
    try {
      if (widget.product == null) {
        await cubit.createProduct(
          name: name,
          kind: _kind,
          sellPrice: price,
          categoryId: _categoryId,
        );
      } else {
        await cubit.updateProduct(
          id: widget.product!.id,
          name: name,
          kind: _kind,
          sellPrice: price,
          categoryId: _categoryId,
          clearCategory: _categoryId == null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      AppMessage.showError(context, cubit.state.error ?? 'Ошибка сохранения');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories.where((c) => !c.archived).toList();
    return EditorScaffold(
      title: widget.product == null ? 'Новый товар' : 'Товар',
      actionLabel: 'Сохранить',
      actionLoading: _saving,
      onAction: _saving ? null : _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _kind,
            decoration: const InputDecoration(labelText: 'Тип'),
            items: [
              for (final k in const ['flower', 'material', 'bouquet'])
                DropdownMenuItem(
                  value: k,
                  child: Text(Labels.productKind(k)),
                ),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _categoryId,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Без категории'),
              ),
              for (final c in cats)
                DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(c.name),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Цена продажи',
              suffixText: '₽',
            ),
          ),
        ],
      ),
    );
  }
}
