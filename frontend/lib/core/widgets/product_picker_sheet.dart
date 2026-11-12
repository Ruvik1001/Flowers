import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';

Future<Product?> showProductPickerSheet({
  required BuildContext context,
  required List<Product> products,
  Set<String>? excludeIds,
  Set<String>? kinds,
  Set<String>? excludeKinds,
  String title = 'Выбор товара',
}) {
  final available = products.where((p) {
    if (p.archived) return false;
    if (excludeIds != null && excludeIds.contains(p.id)) return false;
    if (kinds != null && !kinds.contains(p.kind)) return false;
    if (excludeKinds != null && excludeKinds.contains(p.kind)) return false;
    return true;
  }).toList();

  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ProductPickerBody(
      title: title,
      products: available,
    ),
  );
}

class _ProductPickerBody extends StatefulWidget {
  const _ProductPickerBody({
    required this.title,
    required this.products,
  });

  final String title;
  final List<Product> products;

  @override
  State<_ProductPickerBody> createState() => _ProductPickerBodyState();
}

class _ProductPickerBodyState extends State<_ProductPickerBody> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.products
        : widget.products
            .where(
              (p) =>
                  p.name.toLowerCase().contains(q) ||
                  Labels.productKind(p.kind).toLowerCase().contains(q),
            )
            .toList();

    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Ничего не найдено'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          '${Labels.productKind(p.kind)} · ${formatRub(p.sellPrice)}',
                        ),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
