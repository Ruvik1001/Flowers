import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_cubit.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_state.dart';
import 'package:flowers/features/assembly/presentation/pages/assembly_detail_page.dart';
import 'package:flowers/features/assembly/presentation/pages/assembly_editor_page.dart';

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

class _AssemblyView extends StatefulWidget {
  const _AssemblyView();

  @override
  State<_AssemblyView> createState() => _AssemblyViewState();
}

class _AssemblyViewState extends State<_AssemblyView> {
  Map<String, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    _loadProductNames();
  }

  Future<void> _loadProductNames() async {
    try {
      final products = await Di.I.catalog.listProducts(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _productNames = {for (final p in products) p.id: p.name};
      });
    } catch (_) {}
  }

  String _bouquetName(String id) => _productNames[id] ?? 'Букет';

  Future<void> _openCreate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AssemblyCubit>(),
          child: const AssemblyEditorPage(),
        ),
      ),
    );
    if (ok == true && mounted) {
      await _loadProductNames();
    }
  }

  void _openDetail(Assembly item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssemblyDetailPage(
          assembly: item,
          productNames: _productNames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: const Text('Сборка'),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-assembly',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<AssemblyCubit, AssemblyState>(
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading && state.assemblies.isEmpty,
            error: state.error,
            isEmpty: state.assemblies.isEmpty,
            emptyMessage: 'Нет сборок',
            emptyIcon: Icons.local_florist_outlined,
            onRetry: () => context.read<AssemblyCubit>().load(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: state.assemblies.length,
              itemBuilder: (context, index) {
                final item = state.assemblies[index];
                return EntityListTile(
                  title: Text(_bouquetName(item.bouquetProductId)),
                  subtitle: Text(
                    '× ${item.quantity} · ${formatRub(item.cost)}',
                  ),
                  trailing: StatusChip(
                    label: Labels.assemblyKind(item.kind),
                    tone: StatusTone.accent,
                  ),
                  onTap: () => _openDetail(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
