import 'package:equatable/equatable.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';

class CashierState extends Equatable {
  const CashierState({
    this.loading = false,
    this.shifts = const [],
    this.error,
  });

  final bool loading;
  final List<Shift> shifts;
  final String? error;

  CashierState copyWith({
    bool? loading,
    List<Shift>? shifts,
    String? error,
    bool clearError = false,
  }) {
    return CashierState(
      loading: loading ?? this.loading,
      shifts: shifts ?? this.shifts,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, shifts, error];
}
