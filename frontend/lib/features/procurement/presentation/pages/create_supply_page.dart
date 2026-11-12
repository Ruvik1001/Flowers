import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/core/widgets/entity_dropdowns.dart';
import 'package:flowers/core/widgets/line_editor_list.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/procurement/domain/entities/supplier.dart';
import 'package:flowers/features/procurement/domain/entities/supply_line.dart';
import 'package:flowers/features/procurement/presentation/cubit/procurement_cubit.dart';

class CreateSupplyPage extends StatefulWidget {
  const CreateSupplyPage({
    super.key,
    required this.suppliers,
  });

  final List<Supplier> suppliers;

  @override
  State<CreateSupplyPage> createState() => _CreateSupplyPageState();
}

class _CreateSupplyPageState extends State<CreateSupplyPage> {
  String? _supplierId;
  List<EditableLine> _lines = [];
  List<Product> _products = [];
  var _loadingProducts = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.suppliers.length == 1) {
      _supplierId = widget.suppliers.first.id;
    }
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
      AppMessage.showError(context, 'Не удалось загрузить товары');
    }
  }

  Future<void> _save() async {
    if (_supplierId == null || _supplierId!.isEmpty) {
      AppMessage.showError(context, 'Выберите поставщика');
      return;
    }
    if (_lines.isEmpty) {
      AppMessage.showError(context, 'Добавьте хотя бы один товар');
      return;
    }
    if (_lines.any((l) => l.quantity <= 0)) {
      AppMessage.showError(context, 'Количество должно быть больше 0');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<ProcurementCubit>().createSupply(
            supplierId: _supplierId!,
            lines: [
              for (final line in _lines)
                SupplyLine(
                  productId: line.productId,
                  quantity: line.quantity,
                  ordered: line.quantity,
                  unitCost: line.unitMoney,
                  accepted: 0,
                ),
            ],
          );
      if (!mounted) return;
      AppMessage.showSuccess(context, 'Поставка создана');
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      AppMessage.showError(
        context,
        context.read<ProcurementCubit>().state.error ?? 'Ошибка создания',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: 'Новая поставка',
      actionLabel: 'Создать',
      actionLoading: _saving,
      onAction: _saving || _loadingProducts ? null : _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SupplierDropdown(
            suppliers: widget.suppliers,
            value: _supplierId,
            onChanged: (v) => setState(() => _supplierId = v),
          ),
          const SizedBox(height: 16),
          Text('Позиции', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingProducts)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            LineEditorList(
              lines: _lines,
              products: _products,
              moneyField: LineMoneyField.unitCost,
              moneyLabel: 'Себестоимость',
              onChanged: (next) => setState(() => _lines = next),
            ),
        ],
      ),
    );
  }
}
