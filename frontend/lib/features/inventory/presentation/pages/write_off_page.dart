import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/core/widgets/photo_upload_field.dart';
import 'package:flowers/core/widgets/product_picker_sheet.dart';
import 'package:flowers/core/widgets/qty_stepper.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/inventory/presentation/cubit/inventory_cubit.dart';

class WriteOffPage extends StatefulWidget {
  const WriteOffPage({
    super.key,
    this.initialProductId,
    this.initialProductName,
    this.initialQuantity,
  });

  final String? initialProductId;
  final String? initialProductName;
  final double? initialQuantity;

  @override
  State<WriteOffPage> createState() => _WriteOffPageState();
}

class _WriteOffPageState extends State<WriteOffPage> {
  List<Product> _products = const [];
  String? _productId;
  String _productName = '';
  double _quantity = 1;
  final _reasonCtrl = TextEditingController();
  List<String> _photoIds = [];
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _productId = widget.initialProductId;
    _productName = widget.initialProductName ?? '';
    _quantity = widget.initialQuantity ?? 1;
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final products = await Di.I.catalog.listProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        if (_productId != null && _productName.isEmpty) {
          _productName =
              products.where((p) => p.id == _productId).firstOrNull?.name ??
                  _productId!;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_productId == null || _productId!.isEmpty) {
      AppMessage.showError(context, 'Выберите товар');
      return;
    }
    if (_quantity <= 0) {
      AppMessage.showError(context, 'Количество должно быть больше 0');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      AppMessage.showError(context, 'Укажите причину');
      return;
    }
    if (_photoIds.isEmpty) {
      AppMessage.showError(context, 'Добавьте хотя бы одно фото');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<InventoryCubit>().writeOff(
            productId: _productId!,
            quantity: _quantity,
            reason: _reasonCtrl.text.trim(),
            photoIds: _photoIds,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      AppMessage.showError(
        context,
        context.read<InventoryCubit>().state.error ?? 'Ошибка списания',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: 'Списание',
      actionLabel: 'Списать',
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _productName.isEmpty ? 'Выберите товар' : _productName,
                  ),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Причина'),
                ),
                const SizedBox(height: 12),
                PhotoUploadField(
                  fileIds: _photoIds,
                  onChanged: (ids) => setState(() => _photoIds = ids),
                ),
              ],
            ),
    );
  }
}
