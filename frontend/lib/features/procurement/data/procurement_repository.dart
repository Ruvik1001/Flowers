import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/procurement/domain/entities/supplier.dart';
import 'package:flowers/features/procurement/domain/entities/supply.dart';
import 'package:flowers/features/procurement/domain/entities/supply_line.dart';

class ProcurementRepository {
  ProcurementRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Supplier>> listSuppliers() {
    return _api.get<List<Supplier>>(
      '/procurement/suppliers',
      parse: (data) => asJsonList(data)
          .map((e) => Supplier.fromJson(asJsonMap(e)))
          .toList(),
    );
  }

  Future<Supplier> createSupplier({required String name, String? phone}) {
    return _api.post<Supplier>(
      '/procurement/suppliers',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
      parse: (data) => Supplier.fromJson(asJsonMap(data)),
    );
  }

  Future<List<Supply>> listSupplies() {
    return _api.get<List<Supply>>(
      '/procurement/supplies',
      parse: (data) => asJsonList(data)
          .map((e) => Supply.fromJson(asJsonMap(e)))
          .toList(),
    );
  }

  Future<Supply> createSupply({
    required String supplierId,
    required List<SupplyLine> lines,
  }) {
    return _api.post<Supply>(
      '/procurement/supplies',
      data: {
        'supplier_id': supplierId,
        'lines': lines.map((e) => e.toCreateJson()).toList(),
      },
      parse: (data) => Supply.fromJson(asJsonMap(data)),
    );
  }

  Future<Supply> acceptLine({
    required String supplyId,
    required String productId,
    required double quantity,
  }) {
    return _api.post<Supply>(
      '/procurement/supplies/$supplyId/accept',
      data: {
        'product_id': productId,
        'quantity': moneyToApi(quantity),
      },
      parse: (data) => Supply.fromJson(asJsonMap(data)),
    );
  }
}
