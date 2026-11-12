import 'package:flutter/material.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';
import 'package:flowers/features/procurement/domain/entities/supplier.dart';
import 'package:flowers/features/sales/domain/entities/sale_line.dart';

Widget _menuText(String text) {
  return Text(
    text,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
  );
}

class ProductDropdown extends StatelessWidget {
  const ProductDropdown({
    super.key,
    required this.products,
    required this.value,
    required this.onChanged,
    this.label = 'Товар',
    this.kinds,
    this.excludeKinds,
    this.validator,
  });

  final List<Product> products;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final Set<String>? kinds;
  final Set<String>? excludeKinds;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final items = products.where((p) {
      if (p.archived) return false;
      if (kinds != null && !kinds!.contains(p.kind)) return false;
      if (excludeKinds != null && excludeKinds!.contains(p.kind)) return false;
      return true;
    }).toList();

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: items.any((p) => p.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final p in items)
          DropdownMenuItem(
            value: p.id,
            child: _menuText(
              '${p.name} · ${Labels.productKind(p.kind)} · ${formatRub(p.sellPrice)}',
            ),
          ),
      ],
      onChanged: onChanged,
      validator: validator ??
          (v) => (v == null || v.isEmpty) ? 'Выберите товар' : null,
    );
  }
}

class RecipeDropdown extends StatelessWidget {
  const RecipeDropdown({
    super.key,
    required this.recipes,
    required this.products,
    required this.value,
    required this.onChanged,
    this.label = 'Рецепт',
    this.validator,
  });

  final List<Recipe> recipes;
  final List<Product> products;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final FormFieldValidator<String>? validator;

  String _title(Recipe r) {
    final bouquet = products.where((p) => p.id == r.bouquetId).firstOrNull;
    final name = bouquet?.name ?? 'Букет';
    return '$name · ${r.items.length} комп.';
  }

  @override
  Widget build(BuildContext context) {
    final items = recipes.where((r) => !r.archived).toList();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: items.any((r) => r.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final r in items)
          DropdownMenuItem(
            value: r.id,
            child: _menuText(_title(r)),
          ),
      ],
      onChanged: onChanged,
      validator: validator ??
          (v) => (v == null || v.isEmpty) ? 'Выберите рецепт' : null,
    );
  }
}

class SupplierDropdown extends StatelessWidget {
  const SupplierDropdown({
    super.key,
    required this.suppliers,
    required this.value,
    required this.onChanged,
    this.label = 'Поставщик',
    this.validator,
  });

  final List<Supplier> suppliers;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: suppliers.any((s) => s.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final s in suppliers)
          DropdownMenuItem(
            value: s.id,
            child: _menuText(
              s.phone == null || s.phone!.isEmpty
                  ? s.name
                  : '${s.name} · ${s.phone}',
            ),
          ),
      ],
      onChanged: onChanged,
      validator: validator ??
          (v) => (v == null || v.isEmpty) ? 'Выберите поставщика' : null,
    );
  }
}

class ShiftDropdown extends StatelessWidget {
  const ShiftDropdown({
    super.key,
    required this.shifts,
    required this.value,
    required this.onChanged,
    this.label = 'Смена',
    this.openOnly = false,
    this.allowEmpty = false,
    this.emptyLabel = 'Без смены',
    this.validator,
  });

  final List<Shift> shifts;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool openOnly;
  final bool allowEmpty;
  final String emptyLabel;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final items = shifts.where((s) => !openOnly || s.isOpen).toList();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value == null || value!.isEmpty || items.any((s) => s.id == value)
          ? (value?.isEmpty == true ? null : value)
          : null,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowEmpty)
          DropdownMenuItem(value: '', child: _menuText(emptyLabel)),
        for (final s in items)
          DropdownMenuItem(
            value: s.id,
            child: _menuText(
              '${s.isOpen ? 'Открыта' : 'Закрыта'} · ${s.openedAt ?? '—'}',
            ),
          ),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class SaleLineProductDropdown extends StatelessWidget {
  const SaleLineProductDropdown({
    super.key,
    required this.lines,
    required this.products,
    required this.value,
    required this.onChanged,
    this.label = 'Товар',
    this.validator,
  });

  final List<SaleLine> lines;
  final List<Product> products;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final FormFieldValidator<String>? validator;

  String _title(SaleLine line) {
    final product = products.where((p) => p.id == line.productId).firstOrNull;
    final name = product?.name ?? 'Товар';
    return '$name · ${line.quantity} шт. · ${formatRub(line.unitPrice)}';
  }

  @override
  Widget build(BuildContext context) {
    final unique = <String, SaleLine>{};
    for (final line in lines) {
      unique.putIfAbsent(line.productId, () => line);
    }
    final items = unique.values.toList();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: items.any((l) => l.productId == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final line in items)
          DropdownMenuItem(
            value: line.productId,
            child: _menuText(_title(line)),
          ),
      ],
      onChanged: onChanged,
      validator: validator ??
          (v) => (v == null || v.isEmpty) ? 'Выберите товар' : null,
    );
  }
}

class SupplyLineProductDropdown extends StatelessWidget {
  const SupplyLineProductDropdown({
    super.key,
    required this.productIds,
    required this.products,
    required this.value,
    required this.onChanged,
    this.label = 'Товар линии',
    this.validator,
  });

  final List<String> productIds;
  final List<Product> products;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: productIds.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final id in productIds)
          DropdownMenuItem(
            value: id,
            child: _menuText(
              products.where((p) => p.id == id).firstOrNull?.name ?? 'Товар',
            ),
          ),
      ],
      onChanged: onChanged,
      validator: validator ??
          (v) => (v == null || v.isEmpty) ? 'Выберите товар' : null,
    );
  }
}
