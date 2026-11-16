import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/inventory/domain/entities/folder.dart';
import 'package:flowers/features/inventory/domain/entities/inventory_count.dart';
import 'package:flowers/features/inventory/domain/entities/lot.dart';
import 'package:flowers/features/inventory/domain/entities/write_off.dart';

class InventoryRepository {
  InventoryRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Lot>> listLots() {
    return _api.get<List<Lot>>(
      '/inventory/lots',
      parse: (data) =>
          asJsonList(data).map((e) => Lot.fromJson(asJsonMap(e))).toList(),
    );
  }

  Future<List<Lot>> listExpired() {
    return _api.get<List<Lot>>(
      '/inventory/inventory/expired',
      parse: (data) =>
          asJsonList(data).map((e) => Lot.fromJson(asJsonMap(e))).toList(),
    );
  }

  Future<List<InventoryFolder>> listFolders({bool includeArchived = false}) {
    return _api.get<List<InventoryFolder>>(
      '/inventory/folders',
      query: {'include_archived': includeArchived},
      parse: (data) => asJsonList(data)
          .map((e) => InventoryFolder.fromJson(asJsonMap(e)))
          .toList(),
    );
  }

  Future<InventoryFolder> createFolder({
    required String name,
    int sortOrder = 0,
  }) {
    return _api.post<InventoryFolder>(
      '/inventory/folders',
      data: {
        'name': name,
        'sort_order': sortOrder,
      },
      parse: (data) => InventoryFolder.fromJson(asJsonMap(data)),
    );
  }

  Future<InventoryFolder> updateFolder({
    required String id,
    String? name,
    int? sortOrder,
  }) {
    return _api.patch<InventoryFolder>(
      '/inventory/folders/$id',
      data: {
        if (name != null) 'name': name,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
      parse: (data) => InventoryFolder.fromJson(asJsonMap(data)),
    );
  }

  Future<InventoryFolder> archiveFolder(String id) {
    return _api.post<InventoryFolder>(
      '/inventory/folders/$id/archive',
      parse: (data) => InventoryFolder.fromJson(asJsonMap(data)),
    );
  }

  Future<Lot> createLot({
    required String productId,
    required double quantity,
    required double unitCost,
    String? expiresOn,
  }) {
    return _api.post<Lot>(
      '/inventory/lots',
      data: {
        'product_id': productId,
        'quantity': moneyToApi(quantity),
        'unit_cost': moneyToApi(unitCost),
        if (expiresOn != null && expiresOn.isNotEmpty) 'expires_on': expiresOn,
      },
      parse: (data) => Lot.fromJson(asJsonMap(data)),
    );
  }

  Future<Lot> updateLot({
    required String id,
    double? quantity,
    double? unitCost,
    String? expiresOn,
    bool clearExpiresOn = false,
    String? folderId,
    bool clearFolder = false,
    int? sortOrder,
  }) {
    return _api.patch<Lot>(
      '/inventory/lots/$id',
      data: {
        if (quantity != null) 'quantity': moneyToApi(quantity),
        if (unitCost != null) 'unit_cost': moneyToApi(unitCost),
        if (expiresOn != null) 'expires_on': expiresOn,
        if (clearExpiresOn) 'clear_expires_on': true,
        if (folderId != null) 'folder_id': folderId,
        if (clearFolder) 'clear_folder': true,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
      parse: (data) => Lot.fromJson(asJsonMap(data)),
    );
  }

  Future<void> deleteLot(String id) {
    return _api.delete<void>('/inventory/lots/$id');
  }

  Future<WriteOff> writeOff({
    required String productId,
    required double quantity,
    required String reason,
    required List<String> photoIds,
  }) {
    return _api.post<WriteOff>(
      '/inventory/write-offs',
      data: {
        'product_id': productId,
        'quantity': moneyToApi(quantity),
        'reason': reason,
        'photo_ids': photoIds,
      },
      parse: (data) => WriteOff.fromJson(asJsonMap(data)),
    );
  }

  Future<InventoryCount> inventoryCount({
    required String productId,
    required double actual,
  }) {
    return _api.post<InventoryCount>(
      '/inventory/inventory-counts',
      data: {
        'product_id': productId,
        'actual': moneyToApi(actual),
      },
      parse: (data) => InventoryCount.fromJson(asJsonMap(data)),
    );
  }

  Future<void> consume({
    required String productId,
    required double quantity,
  }) {
    return _api.post<void>(
      '/inventory/inventory/consume',
      data: {
        'product_id': productId,
        'quantity': moneyToApi(quantity),
      },
    );
  }
}
