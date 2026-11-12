import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/product_picker_sheet.dart';
import 'package:flowers/core/widgets/qty_stepper.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';

enum LineMoneyField { none, unitCost, unitPrice }

class EditableLine {
  EditableLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unitMoney = 0,
    this.selected = true,
  });

  String productId;
  String productName;
  double quantity;
  double unitMoney;
  bool selected;
}

class LineEditorList extends StatelessWidget {
  const LineEditorList({
    super.key,
    required this.lines,
    required this.products,
    required this.onChanged,
    this.moneyField = LineMoneyField.none,
    this.moneyLabel,
    this.allowRemove = true,
    this.showSelection = false,
    this.showAddButton = true,
    this.addLabel = 'Добавить товар',
    this.emptyLabel = 'Добавьте хотя бы один товар',
  });

  final List<EditableLine> lines;
  final List<Product> products;
  final ValueChanged<List<EditableLine>> onChanged;
  final LineMoneyField moneyField;
  final String? moneyLabel;
  final bool allowRemove;
  final bool showSelection;
  final bool showAddButton;
  final String addLabel;
  final String emptyLabel;

  Future<void> _add(BuildContext context) async {
    final picked = await showProductPickerSheet(
      context: context,
      products: products,
      excludeIds: lines.map((e) => e.productId).toSet(),
    );
    if (picked == null) return;
    final next = List<EditableLine>.from(lines)
      ..add(
        EditableLine(
          productId: picked.id,
          productName: picked.name,
          quantity: 1,
          unitMoney: moneyField == LineMoneyField.unitPrice
              ? picked.sellPrice
              : 0,
        ),
      );
    onChanged(next);
  }

  void _update(int index, EditableLine Function(EditableLine) mutate) {
    final next = List<EditableLine>.from(lines);
    next[index] = mutate(next[index]);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ),
        for (var i = 0; i < lines.length; i++) ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (showSelection)
                      Checkbox(
                        value: lines[i].selected,
                        onChanged: (v) => _update(
                          i,
                          (line) => EditableLine(
                            productId: line.productId,
                            productName: line.productName,
                            quantity: line.quantity,
                            unitMoney: line.unitMoney,
                            selected: v ?? true,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        lines[i].productName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (allowRemove)
                      IconButton(
                        tooltip: 'Удалить',
                        onPressed: () {
                          final next = List<EditableLine>.from(lines)
                            ..removeAt(i);
                          onChanged(next);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                QtyStepper(
                  value: lines[i].quantity,
                  min: 0,
                  onChanged: (v) => _update(
                    i,
                    (line) => EditableLine(
                      productId: line.productId,
                      productName: line.productName,
                      quantity: v,
                      unitMoney: line.unitMoney,
                      selected: line.selected,
                    ),
                  ),
                ),
                if (moneyField != LineMoneyField.none) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: lines[i].unitMoney.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: moneyLabel ??
                          (moneyField == LineMoneyField.unitCost
                              ? 'Себестоимость'
                              : 'Цена'),
                      suffixText: '₽',
                    ),
                    onChanged: (raw) {
                      final parsed =
                          double.tryParse(raw.replaceAll(',', '.')) ?? 0;
                      _update(
                        i,
                        (line) => EditableLine(
                          productId: line.productId,
                          productName: line.productName,
                          quantity: line.quantity,
                          unitMoney: parsed,
                          selected: line.selected,
                        ),
                      );
                    },
                  ),
                  if (moneyField == LineMoneyField.unitPrice)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Сумма: ${formatRub(lines[i].quantity * lines[i].unitMoney)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (showAddButton)
          OutlinedButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
      ],
    );
  }
}
