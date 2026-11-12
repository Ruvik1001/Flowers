import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';

class AnalyticsRepository {
  AnalyticsRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const reportNames = <String>[
    'revenue-by-day',
    'revenue-by-shift',
    'sales-by-product',
    'stock-turnover',
    'margin',
    'cash-gaps',
    'write-offs',
  ];

  Future<Map<String, dynamic>> getReport(String name) {
    return _api.get<Map<String, dynamic>>(
      '/analytics/reports/$name',
      parse: asJsonMap,
    );
  }
}
