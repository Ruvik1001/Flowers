import 'package:equatable/equatable.dart';
import 'package:flowers/features/procurement/domain/entities/supplier.dart';
import 'package:flowers/features/procurement/domain/entities/supply.dart';

class ProcurementState extends Equatable {
  const ProcurementState({
    this.loading = false,
    this.suppliers = const [],
    this.supplies = const [],
    this.error,
  });

  final bool loading;
  final List<Supplier> suppliers;
  final List<Supply> supplies;
  final String? error;

  ProcurementState copyWith({
    bool? loading,
    List<Supplier>? suppliers,
    List<Supply>? supplies,
    String? error,
    bool clearError = false,
  }) {
    return ProcurementState(
      loading: loading ?? this.loading,
      suppliers: suppliers ?? this.suppliers,
      supplies: supplies ?? this.supplies,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, suppliers, supplies, error];
}
