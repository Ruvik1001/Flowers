import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/responsive.dart';
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

class _AnalyticsView extends StatefulWidget {
  const _AnalyticsView();

  @override
  State<_AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<_AnalyticsView> {
  Map<String, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final products = await Di.I.catalog.listProducts(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _productNames = {for (final p in products) p.id: p.name};
      });
    } catch (_) {}
  }

  String _productName(String? id) {
    if (id == null || id.isEmpty) return 'Товар';
    return _productNames[id] ?? _shortId(id);
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  List<_ReportRow> _rows(String name, Map<String, dynamic> report) {
    switch (name) {
      case 'margin':
        return [
          _ReportRow('Выручка', formatRub(_num(report['revenue']))),
          _ReportRow('Себестоимость', formatRub(_num(report['cost']))),
          _ReportRow('Маржа', formatRub(_num(report['margin']))),
        ];
      case 'revenue-by-day':
      case 'revenue-by-shift':
      case 'cash-gaps':
        final items = (report['items'] as List?) ?? const [];
        return [
          for (final raw in items)
            if (raw is Map)
              _ReportRow(
                name == 'revenue-by-day'
                    ? (raw['key']?.toString() ?? 'День')
                    : _shortId(raw['key']?.toString() ?? 'Смена'),
                formatRub(_num(raw['value'])),
                subtitle: name == 'cash-gaps' ? 'Расхождение' : 'Сумма',
              ),
        ];
      case 'sales-by-product':
      case 'write-offs':
        final items = (report['items'] as List?) ?? const [];
        return [
          for (final raw in items)
            if (raw is Map)
              _ReportRow(
                _productName(raw['product_id']?.toString()),
                formatRub(_num(raw['revenue'] ?? raw['value'])),
                subtitle: 'Кол-во: ${_num(raw['quantity']).toStringAsFixed(2)}',
              ),
        ];
      case 'stock-turnover':
        final items = (report['items'] as List?) ?? const [];
        return [
          for (final raw in items)
            if (raw is Map)
              _ReportRow(
                _productName(raw['product_id']?.toString()),
                'Движение: ${_num(raw['movement']).toStringAsFixed(2)}',
                subtitle: Labels.orDash(raw['status']),
              ),
        ];
      default:
        return [const _ReportRow('Нет данных', '—')];
    }
  }

  bool _isEmpty(String name, Map<String, dynamic>? report) {
    if (report == null) return true;
    if (name == 'margin') {
      return _num(report['revenue']) == 0 &&
          _num(report['cost']) == 0 &&
          _num(report['margin']) == 0;
    }
    final items = report['items'];
    return items is! List || items.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWideNav(context);
    return AppPageScaffold(
      title: const Text('Аналитика'),
      body: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          final report = state.report ?? const <String, dynamic>{};
          final rows = _rows(state.reportName, report);
          final empty = _isEmpty(state.reportName, state.report);

          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final name in AnalyticsRepository.reportNames)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(Labels.report(name)),
                          selected: state.reportName == name,
                          onSelected: (_) =>
                              context.read<AnalyticsCubit>().load(name),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      context.read<AnalyticsCubit>().load(state.reportName),
                  child: AsyncBody(
                    loading: state.loading,
                    error: state.error,
                    isEmpty: !state.loading && empty,
                    emptyMessage: 'Нет данных отчёта',
                    emptyIcon: Icons.insights_outlined,
                    onRetry: () =>
                        context.read<AnalyticsCubit>().load(state.reportName),
                    child: state.reportName == 'margin'
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              SoftCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final row in rows) ...[
                                      Text(
                                        row.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      Text(
                                        row.value,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          )
                        : wide
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                child: SoftCard(
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Показатель')),
                                      DataColumn(label: Text('Значение')),
                                      DataColumn(label: Text('Детали')),
                                    ],
                                    rows: [
                                      for (final row in rows)
                                        DataRow(
                                          cells: [
                                            DataCell(Text(row.title)),
                                            DataCell(Text(row.value)),
                                            DataCell(
                                              Text(row.subtitle ?? ''),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final row = rows[index];
                                  return EntityListTile(
                                    title: Text(row.value),
                                    subtitle: Text(
                                      row.subtitle == null
                                          ? row.title
                                          : '${row.title}\n${row.subtitle}',
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportRow {
  const _ReportRow(this.title, this.value, {this.subtitle});
  final String title;
  final String value;
  final String? subtitle;
}
