import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/features/analytics/data/analytics_repository.dart';
import 'package:flowers/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:flowers/features/analytics/presentation/cubit/analytics_state.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AnalyticsCubit(Di.I.analytics)..load(),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: const Text('Аналитика'),
      body: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SoftCard(
                  child: DropdownButtonFormField<String>(
                    value: state.reportName,
                    decoration: const InputDecoration(
                      labelText: 'Отчёт',
                    ),
                    items: AnalyticsRepository.reportNames
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(Labels.report(name)),
                          ),
                        )
                        .toList(),
                    onChanged: (name) {
                      if (name != null) {
                        context.read<AnalyticsCubit>().load(name);
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: AsyncBody(
                  loading: state.loading,
                  error: state.error,
                  isEmpty: state.report == null || state.report!.isEmpty,
                  emptyMessage: 'Нет данных отчёта',
                  emptyIcon: Icons.insights_outlined,
                  onRetry: () => context.read<AnalyticsCubit>().load(),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    children: _flatten(state.report ?? const {})
                        .map(
                          (row) => EntityListTile(
                            dense: true,
                            title: Text(row.$1),
                            subtitle: Text(row.$2),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _labelKey(String key) {
    // Flattened keys may be "items[0].revenue" — label the leaf segment.
    final leaf = key.contains('.')
        ? key.split('.').last
        : key.contains('[')
            ? key.split('[').first
            : key;
    final leafClean = leaf.contains('[') ? leaf.split('[').first : leaf;
    final labeled = Labels.reportKey(leafClean);
    if (labeled != leafClean) {
      return key.replaceAll(leafClean, labeled);
    }
    return Labels.reportKey(key);
  }

  List<(String, String)> _flatten(
    Map<String, dynamic> data, [
    String prefix = '',
  ]) {
    final rows = <(String, String)>[];
    for (final entry in data.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      if (value is Map) {
        rows.addAll(_flatten(Map<String, dynamic>.from(value), key));
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is Map) {
            rows.addAll(
              _flatten(Map<String, dynamic>.from(item), '$key[$i]'),
            );
          } else {
            rows.add((_labelKey('$key[$i]'), Labels.orDash(item)));
          }
        }
      } else {
        rows.add((_labelKey(key), Labels.orDash(value)));
      }
    }
    return rows;
  }
}
