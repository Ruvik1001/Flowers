import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/procurement/domain/entities/supply_line.dart';
import 'package:flowers/features/procurement/presentation/cubit/procurement_state.dart';
import 'package:flowers/features/procurement/data/procurement_repository.dart';

class AcceptBatchResult {
  const AcceptBatchResult({
    required this.requested,
    required this.succeeded,
    this.error,
  });

  final int requested;
  final int succeeded;
  final String? error;

  bool get partial => succeeded > 0 && succeeded < requested;
  bool get failed => succeeded == 0 && error != null;
}

class ProcurementCubit extends SafeCubit<ProcurementState> {
  ProcurementCubit(this._repository) : super(const ProcurementState());

  final ProcurementRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final suppliers = await _repository.listSuppliers();
      final supplies = await _repository.listSupplies();
      emit(
        state.copyWith(
          loading: false,
          suppliers: suppliers,
          supplies: supplies,
          clearError: true,
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> createSupplier({required String name, String? phone}) async {
    try {
      await _repository.createSupplier(name: name, phone: phone);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> createSupply({
    required String supplierId,
    required List<SupplyLine> lines,
  }) async {
    try {
      await _repository.createSupply(supplierId: supplierId, lines: lines);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> acceptLine({
    required String supplyId,
    required String productId,
    required double quantity,
  }) async {
    try {
      await _repository.acceptLine(
        supplyId: supplyId,
        productId: productId,
        quantity: quantity,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  /// Sequential accepts. Already-successful lines are kept (API has no txn).
  Future<AcceptBatchResult> acceptLines({
    required String supplyId,
    required List<({String productId, double quantity})> lines,
  }) async {
    final actionable =
        lines.where((l) => l.quantity > 0).toList(growable: false);
    var ok = 0;
    String? error;
    for (final line in actionable) {
      try {
        await _repository.acceptLine(
          supplyId: supplyId,
          productId: line.productId,
          quantity: line.quantity,
        );
        ok++;
      } on AppFailure catch (e) {
        error = e.message;
        break;
      } catch (e) {
        error = e.toString();
        break;
      }
    }
    await load();
    return AcceptBatchResult(
      requested: actionable.length,
      succeeded: ok,
      error: error,
    );
  }
}
