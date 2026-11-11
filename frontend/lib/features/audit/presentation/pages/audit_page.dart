import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/features/audit/presentation/cubit/audit_cubit.dart';
import 'package:flowers/features/audit/presentation/cubit/audit_state.dart';

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuditCubit(Di.I.audit)..load(),
      child: const _AuditView(),
    );
  }
}

class _AuditView extends StatefulWidget {
  const _AuditView();

  @override
  State<_AuditView> createState() => _AuditViewState();
}

class _AuditViewState extends State<_AuditView> {
  final _eventCtrl = TextEditingController();
  final _actorCtrl = TextEditingController();
  final _entityTypeCtrl = TextEditingController();
  final _entityIdCtrl = TextEditingController();

  @override
  void dispose() {
    _eventCtrl.dispose();
    _actorCtrl.dispose();
    _entityTypeCtrl.dispose();
    _entityIdCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    context.read<AuditCubit>().load(
          eventName: _eventCtrl.text.trim(),
          actorId: _actorCtrl.text.trim(),
          entityType: _entityTypeCtrl.text.trim(),
          entityId: _entityIdCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аудит'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _applyFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _eventCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Событие'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _actorCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Actor ID'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _entityTypeCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Тип сущности'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _entityIdCtrl,
                        decoration:
                            const InputDecoration(labelText: 'ID сущности'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<AuditCubit, AuditState>(
              builder: (context, state) {
                return AsyncBody(
                  loading: state.loading,
                  error: state.error,
                  isEmpty: state.records.isEmpty,
                  emptyMessage: 'Нет записей аудита',
                  onRetry: _applyFilters,
                  child: ListView.separated(
                    itemCount: state.records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = state.records[index];
                      return ListTile(
                        title: Text(record.eventName),
                        subtitle: Text(
                          '${record.occurredAt}\n'
                          '${record.entityType ?? '—'} ${record.entityId ?? ''}'
                          '${record.actorId != null ? ' · ${record.actorId}' : ''}',
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
