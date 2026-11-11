import 'package:equatable/equatable.dart';
import 'package:flowers/features/sales/domain/entities/sale.dart';

class SalesState extends Equatable {
  const SalesState({
    this.loading = false,
    this.sales = const [],
    this.error,
  });

  final bool loading;
  final List<Sale> sales;
  final String? error;

  SalesState copyWith({
    bool? loading,
    List<Sale>? sales,
    String? error,
    bool clearError = false,
  }) {
    return SalesState(
      loading: loading ?? this.loading,
      sales: sales ?? this.sales,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, sales, error];
}
