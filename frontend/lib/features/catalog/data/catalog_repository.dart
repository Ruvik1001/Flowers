import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';
import 'package:flowers/features/catalog/domain/entities/recipe_item.dart';

class CatalogRepository {
  CatalogRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Product>> listProducts({bool includeArchived = false}) {
    return _api.get<List<Product>>(
      '/catalog/products',
      query: {'include_archived': includeArchived},
      parse: (data) => asJsonList(data)
          .map((e) => Product.fromJson(asJsonMap(e)))
          .toList(),
    );
  }

  Future<Product> createProduct({
    required String name,
    required String kind,
    required double sellPrice,
  }) {
    return _api.post<Product>(
      '/catalog/products',
      data: {
        'name': name,
        'kind': kind,
        'sell_price': moneyToApi(sellPrice),
      },
      parse: (data) => Product.fromJson(asJsonMap(data)),
    );
  }

  Future<void> archiveProduct(String id) {
    return _api.post<void>('/catalog/products/$id/archive');
  }

  Future<List<Recipe>> listRecipes({bool includeArchived = false}) {
    return _api.get<List<Recipe>>(
      '/catalog/recipes',
      query: {'include_archived': includeArchived},
      parse: (data) => asJsonList(data)
          .map((e) => Recipe.fromJson(asJsonMap(e)))
          .toList(),
    );
  }

  Future<Recipe> createRecipe({
    required String bouquetId,
    required List<RecipeItem> items,
  }) {
    return _api.post<Recipe>(
      '/catalog/recipes',
      data: {
        'bouquet_id': bouquetId,
        'items': items.map((e) => e.toJson()).toList(),
      },
      parse: (data) => Recipe.fromJson(asJsonMap(data)),
    );
  }

  Future<void> archiveRecipe(String id) {
    return _api.post<void>('/catalog/recipes/$id/archive');
  }
}
