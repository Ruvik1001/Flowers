import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/core/widgets/product_picker_sheet.dart';
import 'package:flowers/core/widgets/qty_stepper.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/inventory/domain/entities/lot.dart';
import 'package:flowers/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:flowers/features/inventory/presentation/pages/write_off_page.dart';

class InventoryCountPage extends StatefulWidget {
  const InventoryCountPage({super.key});

  @override
  State<InventoryCountPage> createState() => _InventoryCountPageState();
}

class _InventoryCountPageState extends State<InventoryCountPage> {
  List<Product> _products = const [];
  List<Lot> _lots = const [];
  String? _productId;
  String _productName = '';
  double _actual = 0;
  double? _expected;
  double? _discrepancy;
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lots = context.read<InventoryCubit>().state.lots;
    try {
      final products = await Di.I.catalog.listProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _lots = lots;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lots = lots;
        _loading = false;
      });
    }
  }

  void _recalcExpected(String productId) {
    final sum = _lots
        .where((l) => l.productId == productId)
        .fold<double>(0, (s, l) => s + l.quantity);
    setState(() {
      _expected = sum;
      _actual = sum;
      _discrepancy = null;
    });
  }

  Future<void> _save() async {
    if (_productId == null) {
      AppMessage.showError(context, 'Выберите товар');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<InventoryCubit>().inventoryCount(
            productId: _productId!,
            actual: _actual,
          );
      final expected = _expected ?? 0;
      final delta = _actual - expected;
      if (!mounted) return;
      setState(() => _discrepancy = delta);
      AppMessage.showSuccess(
        context,
        'Расхождение: ${delta.toStringAsFixed(2)}',
      );
    } catch (_) {
      if (!mounted) return;
      AppMessage.showError(
        context,
        context.read<InventoryCubit>().state.error ?? 'Ошибка',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: 'Инвентаризация',
      actionLabel: 'Зафиксировать',
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
                Text(
                  'Счёт только фиксирует расхождение и не меняет остаток.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 12),
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
                    _recalcExpected(picked.id);
                  },
                ),
                if (_expected != null)
                  SoftCard(
                    child: Text(
                      'По партиям сейчас: ${_expected!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 12),
                QtyStepper(
                  label: 'Факт',
                  value: _actual,
                  min: 0,
                  onChanged: (v) => setState(() => _actual = v),
                ),
                if (_discrepancy != null) ...[
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Расхождение: ${_discrepancy!.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_discrepancy! < 0) ...[
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<InventoryCubit>(),
                                    child: WriteOffPage(
                                      initialProductId: _productId,
                                      initialProductName: _productName,
                                      initialQuantity: -_discrepancy!,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: const Text('Списать расхождение'),
                          ),
                        ],
                        if (_discrepancy! > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Излишек ${_discrepancy!.toStringAsFixed(2)} ед. — оформите приход через приёмку/партию.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
