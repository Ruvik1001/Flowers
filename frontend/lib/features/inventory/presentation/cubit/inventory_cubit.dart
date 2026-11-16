import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/inventory/presentation/cubit/inventory_state.dart';
import 'package:flowers/features/inventory/data/inventory_repository.dart';

class InventoryCubit extends SafeCubit<InventoryState> {
  InventoryCubit(this._repository) : super(const InventoryState());

  final InventoryRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final lots = await _repository.listLots();
      final folders = await _repository.listFolders();
      final expired = await _repository.listExpired();
      emit(
        state.copyWith(
          loading: false,
          lots: lots,
          folders: folders,
          expired: expired,
          clearError: true,
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> createLot({
    required String productId,
    required double quantity,
    required double unitCost,
    String? expiresOn,
  }) async {
    try {
      await _repository.createLot(
        productId: productId,
        quantity: quantity,
        unitCost: unitCost,
        expiresOn: expiresOn,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> updateLot({
    required String id,
    double? quantity,
    double? unitCost,
    String? expiresOn,
    bool clearExpiresOn = false,
    String? folderId,
    bool clearFolder = false,
    int? sortOrder,
  }) async {
    try {
      await _repository.updateLot(
        id: id,
        quantity: quantity,
        unitCost: unitCost,
        expiresOn: expiresOn,
        clearExpiresOn: clearExpiresOn,
        folderId: folderId,
        clearFolder: clearFolder,
        sortOrder: sortOrder,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> deleteLot(String id) async {
    try {
      await _repository.deleteLot(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> createFolder({required String name}) async {
    try {
      final maxOrder = state.folders.isEmpty
          ? 0
          : state.folders.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);
      await _repository.createFolder(name: name, sortOrder: maxOrder + 1);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> archiveFolder(String id) async {
    try {
      await _repository.archiveFolder(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> reorderLots(List<String> orderedIds) async {
    try {
      for (var i = 0; i < orderedIds.length; i++) {
        await _repository.updateLot(id: orderedIds[i], sortOrder: i);
      }
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> writeOff({
    required String productId,
    required double quantity,
    required String reason,
    required List<String> photoIds,
  }) async {
    try {
      final result = await _repository.writeOff(
        productId: productId,
        quantity: quantity,
        reason: reason,
        photoIds: photoIds,
      );
      emit(state.copyWith(lastMessage: 'Списание ${result.id}'));
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> inventoryCount({
    required String productId,
    required double actual,
  }) async {
    try {
      final result = await _repository.inventoryCount(
        productId: productId,
        actual: actual,
      );
      emit(
        state.copyWith(
          lastMessage:
              'Инвентаризация ${result.id}: расхождение ${result.discrepancy}',
        ),
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> consume({
    required String productId,
    required double quantity,
  }) async {
    try {
      await _repository.consume(productId: productId, quantity: quantity);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }
}
