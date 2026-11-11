import 'package:equatable/equatable.dart';
import 'package:flowers/features/inventory/domain/entities/lot.dart';

class InventoryState extends Equatable {
  const InventoryState({
    this.loading = false,
    this.lots = const [],
    this.expired = const [],
    this.error,
    this.lastMessage,
  });

  final bool loading;
  final List<Lot> lots;
  final List<Lot> expired;
  final String? error;
  final String? lastMessage;

  InventoryState copyWith({
    bool? loading,
    List<Lot>? lots,
    List<Lot>? expired,
    String? error,
    String? lastMessage,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return InventoryState(
      loading: loading ?? this.loading,
      lots: lots ?? this.lots,
      expired: expired ?? this.expired,
      error: clearError ? null : (error ?? this.error),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }

  @override
  List<Object?> get props => [loading, lots, expired, error, lastMessage];
}
