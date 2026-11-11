import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/widgets/async_body.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика')),
      body: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: state.reportName,
                  decoration: const InputDecoration(
                    labelText: 'Отчёт',
                    border: OutlineInputBorder(),
                  ),
                  items: AnalyticsRepository.reportNames
                      .map(
                        (name) => DropdownMenuItem(
                          value: name,
                          child: Text(name),
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
              Expanded(
                child: AsyncBody(
                  loading: state.loading,
                  error: state.error,
                  isEmpty: state.report == null || state.report!.isEmpty,
                  emptyMessage: 'Нет данных отчёта',
                  onRetry: () => context.read<AnalyticsCubit>().load(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _flatten(state.report ?? const {})
                        .map(
                          (row) => ListTile(
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

  List<(String, String)> _flatten(Map<String, dynamic> data, [String prefix = '']) {
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
            rows.addAll(_flatten(Map<String, dynamic>.from(item), '$key[$i]'));
          } else {
            rows.add(('$key[$i]', item.toString()));
          }
        }
      } else {
        rows.add((key, value?.toString() ?? 'null'));
      }
    }
    return rows;
  }
}
