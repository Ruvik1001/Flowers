import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/audit/presentation/cubit/audit_state.dart';
import 'package:flowers/features/audit/data/audit_repository.dart';

class AuditCubit extends SafeCubit<AuditState> {
  AuditCubit(this._repository) : super(const AuditState());

  final AuditRepository _repository;

  Future<void> load({
    String? eventName,
    String? actorId,
    String? entityType,
    String? entityId,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final records = await _repository.list(
        eventName: eventName,
        actorId: actorId,
        entityType: entityType,
        entityId: entityId,
      );
      emit(
        state.copyWith(loading: false, records: records, clearError: true),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
