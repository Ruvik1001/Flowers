import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/editor_scaffold.dart';
import 'package:flowers/core/widgets/line_editor_list.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/procurement/domain/entities/supply.dart';
import 'package:flowers/features/procurement/presentation/cubit/procurement_cubit.dart';

class AcceptSupplyPage extends StatefulWidget {
  const AcceptSupplyPage({super.key, required this.supply});

  final Supply supply;

  @override
  State<AcceptSupplyPage> createState() => _AcceptSupplyPageState();
}

class _AcceptSupplyPageState extends State<AcceptSupplyPage> {
  List<EditableLine> _lines = [];
  List<Product> _products = [];
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final products = await Di.I.catalog.listProducts(includeArchived: true);
      final names = {for (final p in products) p.id: p.name};
      final remaining = <EditableLine>[];
      for (final line in widget.supply.lines) {
        final left = line.ordered - line.accepted;
        if (left <= 0) continue;
        remaining.add(
          EditableLine(
            productId: line.productId,
            productName: names[line.productId] ?? line.productId,
            quantity: left,
            selected: true,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _products = products;
        _lines = remaining;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppMessage.showError(context, 'Не удалось загрузить товары');
    }
  }

  Future<void> _accept({required bool selectedOnly}) async {
    final payload = _lines
        .where((l) => !selectedOnly || l.selected)
        .where((l) => l.quantity > 0)
        .map((l) => (productId: l.productId, quantity: l.quantity))
        .toList();
    if (payload.isEmpty) {
      AppMessage.showError(context, 'Нет позиций для приёмки');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await context.read<ProcurementCubit>().acceptLines(
            supplyId: widget.supply.id,
            lines: payload,
          );
      if (!mounted) return;
      if (result.failed) {
        AppMessage.showError(context, result.error ?? 'Ошибка приёмки');
        return;
      }
      if (result.partial) {
        AppMessage.showError(
          context,
          'Принято ${result.succeeded} из ${result.requested}. ${result.error ?? ''}',
        );
        Navigator.pop(context, true);
        return;
      }
      AppMessage.showSuccess(
        context,
        'Принято ${result.succeeded} поз.',
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: 'Приёмка поставки',
      actionLabel: 'Принять всё',
      actionLoading: _saving,
      onAction: _saving || _loading || _lines.isEmpty
          ? null
          : () => _accept(selectedOnly: false),
      bottomBar: _lines.isEmpty || _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _accept(selectedOnly: true),
                  child: const Text('Принять выбранное'),
                ),
              ),
            ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : _lines.isEmpty
              ? Text(
                  'Все позиции уже приняты',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.muted,
                      ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Осталось принять. Количество по умолчанию — остаток.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                    const SizedBox(height: 12),
                    LineEditorList(
                      lines: _lines,
                      products: _products,
                      moneyField: LineMoneyField.none,
                      allowRemove: false,
                      showSelection: true,
                      showAddButton: false,
                      onChanged: (next) => setState(() => _lines = next),
                    ),
                  ],
                ),
    );
  }
}
