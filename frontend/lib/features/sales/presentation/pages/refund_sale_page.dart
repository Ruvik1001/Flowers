import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/core/widgets/photo_upload_field.dart';
import 'package:flowers/core/widgets/product_picker_sheet.dart';
import 'package:flowers/core/widgets/qty_stepper.dart';
import 'package:flowers/features/cashier/presentation/cubit/cashier_cubit.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/sales/domain/entities/sale.dart';
import 'package:flowers/features/sales/presentation/cubit/sales_cubit.dart';

class RefundSalePage extends StatefulWidget {
  const RefundSalePage({
    super.key,
    required this.sale,
    this.openShiftId,
  });

  final Sale sale;
  final String? openShiftId;

  @override
  State<RefundSalePage> createState() => _RefundSalePageState();
}

class _RefundSalePageState extends State<RefundSalePage> {
  late final TextEditingController _amountCtrl;
  var _kind = 'money_only';
  String? _productId;
  String _productName = '';
  double _quantity = 1;
  List<String> _photoIds = [];
  List<Product> _products = [];
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: widget.sale.total.toStringAsFixed(2));
    if (widget.sale.lines.isNotEmpty) {
      _productId = widget.sale.lines.first.productId;
      _quantity = widget.sale.lines.first.quantity;
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await Di.I.catalog.listProducts(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _products = products;
        _productName = products
                .where((p) => p.id == _productId)
                .firstOrNull
                ?.name ??
            _productId ??
            '';
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      AppMessage.showError(context, 'Укажите сумму');
      return;
    }
    if (_kind == 'defect_write_off' && _photoIds.isEmpty) {
      AppMessage.showError(context, 'Нужно фото для списания брака');
      return;
    }

    final sales = context.read<SalesCubit>();
    final cashier = context.read<CashierCubit>();
    setState(() => _saving = true);
    try {
      await sales.createRefund(
        saleId: widget.sale.id,
        amount: amount,
        kind: _kind,
        productId: _kind == 'money_only' ? null : _productId,
        quantity: _kind == 'money_only' ? null : _quantity,
        photoIds: _photoIds,
      );
      final shiftId = widget.openShiftId;
      if (shiftId != null) {
        try {
          await cashier.cash(
            shiftId: shiftId,
            amount: amount,
            refund: true,
          );
        } catch (_) {
          // Sale refund succeeded; cash drawer update is best-effort.
        }
      }
      if (!mounted) return;
      AppMessage.showSuccess(context, 'Возврат оформлен');
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      AppMessage.showError(
        context,
        sales.state.error ?? 'Ошибка возврата',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsStock = _kind == 'stock_back' || _kind == 'defect_write_off';
    return EditorScaffold(
      title: 'Возврат',
      actionLabel: 'Оформить',
      actionLoading: _saving,
      onAction: _saving ? null : _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Чек ${formatRub(widget.sale.total)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Тип'),
            items: const [
              DropdownMenuItem(
                value: 'money_only',
                child: Text('Только деньги'),
              ),
              DropdownMenuItem(
                value: 'stock_back',
                child: Text('Вернуть на склад'),
              ),
              DropdownMenuItem(
                value: 'defect_write_off',
                child: Text('Брак / списание'),
              ),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Сумма'),
          ),
          if (needsStock) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_productName.isEmpty ? 'Товар' : _productName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showProductPickerSheet(
                  context: context,
                  products: _products,
                );
                if (picked == null) return;
                setState(() {
                  _productId = picked.id;
                  _productName = picked.name;
                });
              },
            ),
            QtyStepper(
              label: 'Количество',
              value: _quantity,
              min: 0,
              onChanged: (v) => setState(() => _quantity = v),
            ),
          ],
          if (_kind == 'defect_write_off') ...[
            const SizedBox(height: 12),
            PhotoUploadField(
              fileIds: _photoIds,
              onChanged: (ids) => setState(() => _photoIds = ids),
            ),
          ],
        ],
      ),
    );
  }
}
