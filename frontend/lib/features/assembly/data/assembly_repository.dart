import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';

class AssemblyRepository {
  AssemblyRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Assembly>> listAssemblies() {
    return _api.get<List<Assembly>>(
      '/assembly/assemblies',
      parse: (data) => asJsonList(data)
          .map((e) => Assembly.fromJson(asJsonMap(e)))
          .toList(),
    );
  }

  Future<Assembly> createAssembly({
    required String bouquetProductId,
    required double quantity,
    required String kind,
    required List<AssemblyComponent> components,
    String? recipeId,
  }) {
    return _api.post<Assembly>(
      '/assembly/assemblies',
      data: {
        'bouquet_product_id': bouquetProductId,
        'quantity': moneyToApi(quantity),
        'kind': kind,
        'components': components.map((e) => e.toJson()).toList(),
        if (recipeId != null && recipeId.isNotEmpty) 'recipe_id': recipeId,
      },
      parse: (data) => Assembly.fromJson(asJsonMap(data)),
    );
  }
}
