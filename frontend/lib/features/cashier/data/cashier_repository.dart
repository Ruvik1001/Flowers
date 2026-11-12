import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/cashier/domain/entities/shift.dart';

class CashierRepository {
  CashierRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Shift>> listShifts() {
    return _api.get<List<Shift>>(
      '/cashier/shifts',
      parse: (data) =>
          asJsonList(data).map((e) => Shift.fromJson(asJsonMap(e))).toList(),
    );
  }

  Future<Shift> open({
    required String cashierId,
    required double openingCash,
  }) {
    return _api.post<Shift>(
      '/cashier/shifts',
      data: {
        'cashier_id': cashierId,
        'opening_cash': moneyToApi(openingCash),
      },
      parse: (data) => Shift.fromJson(asJsonMap(data)),
    );
  }

  Future<Shift> cash({
    required String shiftId,
    required double amount,
    bool refund = false,
  }) {
    return _api.post<Shift>(
      '/cashier/shifts/$shiftId/cash',
      data: {
        'amount': moneyToApi(amount),
        'refund': refund,
      },
      parse: (data) => Shift.fromJson(asJsonMap(data)),
    );
  }

  Future<Shift> close({
    required String shiftId,
    required double actualCash,
  }) {
    return _api.post<Shift>(
      '/cashier/shifts/$shiftId/close',
      data: {'actual_cash': moneyToApi(actualCash)},
      parse: (data) => Shift.fromJson(asJsonMap(data)),
    );
  }
}
