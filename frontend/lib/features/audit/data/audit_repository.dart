import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/features/audit/domain/entities/audit_record.dart';

class AuditRepository {
  AuditRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<AuditRecord>> list({
    String? eventName,
    String? actorId,
    String? entityType,
    String? entityId,
  }) {
    return _api.get<List<AuditRecord>>(
      '/audit/audit',
      query: {
        if (eventName != null && eventName.isNotEmpty) 'event_name': eventName,
        if (actorId != null && actorId.isNotEmpty) 'actor_id': actorId,
        if (entityType != null && entityType.isNotEmpty)
          'entity_type': entityType,
        if (entityId != null && entityId.isNotEmpty) 'entity_id': entityId,
      },
      parse: (data) => asJsonList(data)
          .map((e) => AuditRecord.fromJson(asJsonMap(e)))
          .toList(),
    );
  }
}
