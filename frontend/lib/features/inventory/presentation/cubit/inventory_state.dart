import 'package:equatable/equatable.dart';
import 'package:flowers/features/inventory/domain/entities/folder.dart';
import 'package:flowers/features/inventory/domain/entities/lot.dart';

class InventoryState extends Equatable {
  const InventoryState({
    this.loading = false,
    this.lots = const [],
    this.folders = const [],
    this.expired = const [],
    this.error,
    this.lastMessage,
  });

  final bool loading;
  final List<Lot> lots;
  final List<InventoryFolder> folders;
  final List<Lot> expired;
  final String? error;
  final String? lastMessage;

  InventoryState copyWith({
    bool? loading,
    List<Lot>? lots,
    List<InventoryFolder>? folders,
    List<Lot>? expired,
    String? error,
    String? lastMessage,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return InventoryState(
      loading: loading ?? this.loading,
      lots: lots ?? this.lots,
      folders: folders ?? this.folders,
      expired: expired ?? this.expired,
      error: clearError ? null : (error ?? this.error),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }

  @override
  List<Object?> get props =>
      [loading, lots, folders, expired, error, lastMessage];
}
