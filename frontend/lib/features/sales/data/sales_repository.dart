import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/sales/domain/entities/payment.dart';
import 'package:flowers/features/sales/domain/entities/refund.dart';
import 'package:flowers/features/sales/domain/entities/sale.dart';
import 'package:flowers/features/sales/domain/entities/sale_line.dart';

class SalesRepository {
  SalesRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Sale>> listSales() {
    return _api.get<List<Sale>>(
      '/sales/sales',
      parse: (data) =>
          asJsonList(data).map((e) => Sale.fromJson(asJsonMap(e))).toList(),
    );
  }

  Future<Sale> createSale({
    required List<SaleLine> lines,
    required List<Payment> payments,
    String? shiftId,
  }) {
    return _api.post<Sale>(
      '/sales/sales',
      data: {
        'lines': lines.map((e) => e.toJson()).toList(),
        'payments': payments.map((e) => e.toJson()).toList(),
        if (shiftId != null && shiftId.isNotEmpty) 'shift_id': shiftId,
      },
      parse: (data) => Sale.fromJson(asJsonMap(data)),
    );
  }

  Future<Refund> createRefund({
    required String saleId,
    required double amount,
    required String kind,
    String? productId,
    double? quantity,
    List<String> photoIds = const [],
  }) {
    return _api.post<Refund>(
      '/sales/sales/$saleId/refunds',
      data: {
        'amount': moneyToApi(amount),
        'kind': kind,
        if (productId != null && productId.isNotEmpty) 'product_id': productId,
        if (quantity != null) 'quantity': moneyToApi(quantity),
        if (photoIds.isNotEmpty) 'photo_ids': photoIds,
      },
      parse: (data) => Refund.fromJson(asJsonMap(data)),
    );
  }
}
