import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_cubit.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_state.dart';

class AssemblyPage extends StatelessWidget {
  const AssemblyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssemblyCubit(Di.I.assembly)..load(),
      child: const _AssemblyView(),
    );
  }
}

class _AssemblyView extends StatelessWidget {
  const _AssemblyView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сборка')),
      body: BlocBuilder<AssemblyCubit, AssemblyState>(
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading && state.assemblies.isEmpty,
            error: state.error,
            isEmpty: state.assemblies.isEmpty,
            emptyMessage: 'Нет сборок',
            onRetry: () => context.read<AssemblyCubit>().load(),
            child: ListView.separated(
              itemCount: state.assemblies.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = state.assemblies[index];
                return ListTile(
                  title: Text(item.bouquetProductId),
                  subtitle: Text(
                    '${item.kind} × ${item.quantity} · ${formatRub(item.cost)}',
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _showCreateDialog(BuildContext context) async {
  final bouquetCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final componentCtrl = TextEditingController();
  final componentQtyCtrl = TextEditingController(text: '1');
  final recipeCtrl = TextEditingController();
  var kind = 'free';
  final cubit = context.read<AssemblyCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новая сборка'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: bouquetCtrl,
                    decoration:
                        const InputDecoration(labelText: 'ID букета-товара'),
                  ),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                  DropdownButtonFormField<String>(
                    value: kind,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const [
                      DropdownMenuItem(value: 'free', child: Text('Свободная')),
                      DropdownMenuItem(
                        value: 'recipe',
                        child: Text('По рецепту'),
                      ),
                    ],
                    onChanged: (v) => setState(() => kind = v ?? kind),
                  ),
                  if (kind == 'recipe')
                    TextField(
                      controller: recipeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'ID рецепта'),
                    ),
                  TextField(
                    controller: componentCtrl,
                    decoration:
                        const InputDecoration(labelText: 'ID компонента'),
                  ),
                  TextField(
                    controller: componentQtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Кол-во компонента'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Собрать'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ok != true) return;

  try {
    await cubit.create(
      bouquetProductId: bouquetCtrl.text.trim(),
      quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0,
      kind: kind,
      recipeId: recipeCtrl.text.trim(),
      components: [
        AssemblyComponent(
          productId: componentCtrl.text.trim(),
          quantity:
              double.tryParse(componentQtyCtrl.text.replaceAll(',', '.')) ?? 0,
        ),
      ],
    );
    if (context.mounted) {
      AppMessage.showSuccess(context, 'Сборка создана');
    }
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка сборки');
    }
  }
}
