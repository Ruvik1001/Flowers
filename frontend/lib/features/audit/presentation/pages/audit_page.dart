import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/features/audit/presentation/cubit/audit_cubit.dart';
import 'package:flowers/features/audit/presentation/cubit/audit_state.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_state.dart';

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
  /// null = Все, 'me' = Я
  String? _actorFilter;
  String? _eventName;
  String? _entityId;
  String? _entityType;

  String? get _currentUserId {
    final auth = context.read<AuthCubit>().state;
    if (auth is Authenticated) return auth.user.id;
    return null;
  }

  void _applyFilters() {
    final actorRaw = _actorFilter;
    final actorId = actorRaw == 'me' ? _currentUserId : null;
    context.read<AuditCubit>().load(
          eventName: _eventName,
          actorId: actorId,
          entityType: _entityType,
          entityId: _entityId,
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
            child: BlocBuilder<AuditCubit, AuditState>(
              builder: (context, state) {
                final entityIds = state.records
                    .map((r) => r.entityId)
                    .whereType<String>()
                    .where((id) => id.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final entityTypes = state.records
                    .map((r) => r.entityType)
                    .whereType<String>()
                    .where((t) => t.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _eventName,
                            decoration: const InputDecoration(
                              labelText: 'Событие',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Все'),
                              ),
                              for (final name in Labels.knownAuditEvents)
                                DropdownMenuItem<String?>(
                                  value: name,
                                  child: Text(Labels.auditEvent(name)),
                                ),
                            ],
                            onChanged: (v) => setState(() => _eventName = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _actorFilter,
                            decoration: const InputDecoration(
                              labelText: 'Исполнитель',
                            ),
                            items: const [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Все'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'me',
                                child: Text('Я'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _actorFilter = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: entityTypes.contains(_entityType)
                                ? _entityType
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Тип сущности',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Все'),
                              ),
                              for (final t in entityTypes)
                                DropdownMenuItem<String?>(
                                  value: t,
                                  child: Text(Labels.entityType(t)),
                                ),
                            ],
                            onChanged: (v) => setState(() => _entityType = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: entityIds.contains(_entityId)
                                ? _entityId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Сущность',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Все'),
                              ),
                              for (final id in entityIds)
                                DropdownMenuItem<String?>(
                                  value: id,
                                  child: Text(id, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() => _entityId = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
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
                      final entity = [
                        if (record.entityType != null &&
                            record.entityType!.isNotEmpty)
                          Labels.entityType(record.entityType!),
                        if (record.entityId != null &&
                            record.entityId!.isNotEmpty)
                          record.entityId!,
                      ].join(' ');
                      return ListTile(
                        title: Text(Labels.auditEvent(record.eventName)),
                        subtitle: Text(
                          '${record.occurredAt}\n'
                          '${entity.isEmpty ? Labels.orDash(null) : entity}',
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
