import 'package:flutter/material.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/section_header.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';

class AssemblyDetailPage extends StatelessWidget {
  const AssemblyDetailPage({
    super.key,
    required this.assembly,
    required this.productNames,
  });

  final Assembly assembly;
  final Map<String, String> productNames;

  String _name(String id) => productNames[id] ?? 'Товар';

  @override
  Widget build(BuildContext context) {
    final bouquet = _name(assembly.bouquetProductId);
    return AppPageScaffold(
      title: Text(bouquet),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bouquet,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      StatusChip(
                        label: Labels.assemblyKind(assembly.kind),
                        tone: StatusTone.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Количество: ${assembly.quantity}'),
                  Text('Себестоимость: ${formatRub(assembly.cost)}'),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: 'Состав',
            subtitle: 'Компоненты сборки',
          ),
          if (assembly.components.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Состав не указан'),
            )
          else
            ...assembly.components.map(
              (c) => EntityListTile(
                title: Text(_name(c.productId)),
                subtitle: Text('× ${c.quantity}'),
              ),
            ),
        ],
      ),
    );
  }
}
