import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/json_utils.dart';

class AuditRecord extends Equatable {
  const AuditRecord({
    required this.eventId,
    required this.eventName,
    required this.occurredAt,
    required this.payload,
    this.actorId,
    this.entityType,
    this.entityId,
  });

  final String eventId;
  final String eventName;
  final String occurredAt;
  final Map<String, dynamic> payload;
  final String? actorId;
  final String? entityType;
  final String? entityId;

  factory AuditRecord.fromJson(Map<String, dynamic> json) {
    return AuditRecord(
      eventId: json['event_id']?.toString() ?? '',
      eventName: json['event_name']?.toString() ?? '',
      occurredAt: json['occurred_at']?.toString() ?? '',
      payload: asJsonMap(json['payload']),
      actorId: json['actor_id']?.toString(),
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [eventId, eventName, occurredAt, payload, actorId, entityType, entityId];
}
