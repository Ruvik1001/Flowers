import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/cashier/presentation/cubit/cashier_state.dart';
import 'package:flowers/features/cashier/data/cashier_repository.dart';

class CashierCubit extends SafeCubit<CashierState> {
  CashierCubit(this._repository) : super(const CashierState());

  final CashierRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final shifts = await _repository.listShifts();
      emit(state.copyWith(loading: false, shifts: shifts, clearError: true));
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> open({
    required String cashierId,
    required double openingCash,
  }) async {
    try {
      await _repository.open(cashierId: cashierId, openingCash: openingCash);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> cash({
    required String shiftId,
    required double amount,
    bool refund = false,
  }) async {
    try {
      await _repository.cash(
        shiftId: shiftId,
        amount: amount,
        refund: refund,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> closeShift({
    required String shiftId,
    required double actualCash,
  }) async {
    try {
      await _repository.close(shiftId: shiftId, actualCash: actualCash);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }
}
