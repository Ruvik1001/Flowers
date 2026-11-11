import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/sales/domain/entities/payment.dart';
import 'package:flowers/features/sales/domain/entities/sale_line.dart';
import 'package:flowers/features/sales/presentation/cubit/sales_state.dart';
import 'package:flowers/features/sales/data/sales_repository.dart';

class SalesCubit extends SafeCubit<SalesState> {
  SalesCubit(this._repository) : super(const SalesState());

  final SalesRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final sales = await _repository.listSales();
      emit(state.copyWith(loading: false, sales: sales, clearError: true));
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> createSale({
    required List<SaleLine> lines,
    required List<Payment> payments,
    String? shiftId,
  }) async {
    try {
      await _repository.createSale(
        lines: lines,
        payments: payments,
        shiftId: shiftId,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> createRefund({
    required String saleId,
    required double amount,
    required String kind,
    String? productId,
    double? quantity,
    List<String> photoIds = const [],
  }) async {
    try {
      await _repository.createRefund(
        saleId: saleId,
        amount: amount,
        kind: kind,
        productId: productId,
        quantity: quantity,
        photoIds: photoIds,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }
}
