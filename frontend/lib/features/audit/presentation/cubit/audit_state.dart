import 'package:equatable/equatable.dart';
import 'package:flowers/features/audit/domain/entities/audit_record.dart';

class AuditState extends Equatable {
  const AuditState({
    this.loading = false,
    this.records = const [],
    this.error,
  });

  final bool loading;
  final List<AuditRecord> records;
  final String? error;

  AuditState copyWith({
    bool? loading,
    List<AuditRecord>? records,
    String? error,
    bool clearError = false,
  }) {
    return AuditState(
      loading: loading ?? this.loading,
      records: records ?? this.records,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, records, error];
}
