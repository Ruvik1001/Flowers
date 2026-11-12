import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/catalog/domain/entities/category.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';
import 'package:flowers/features/catalog/domain/entities/recipe_item.dart';

class CatalogRepository {
  CatalogRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Category>> listCategories({bool includeArchived = false}) {
    return _api.get<List<Category>>(
      '/catalog/categories',
      query: {'include_archived': includeArchived},
      parse: (data) => asJsonList(data)
          .map((e) => Category.fromJson(asJsonMap(e)))
          .toList(),
    );
  }

  Future<Category> createCategory({required String name}) {
    return _api.post<Category>(
      '/catalog/categories',
      data: {'name': name},
      parse: (data) => Category.fromJson(asJsonMap(data)),
    );
  }

  Future<void> archiveCategory(String id) {
    return _api.post<void>('/catalog/categories/$id/archive');
  }

  Future<void> unarchiveCategory(String id) {
    return _api.post<void>('/catalog/categories/$id/unarchive');
  }

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
    String? categoryId,
  }) {
    return _api.post<Product>(
      '/catalog/products',
      data: {
        'name': name,
        'kind': kind,
        'sell_price': moneyToApi(sellPrice),
        if (categoryId != null) 'category_id': categoryId,
      },
      parse: (data) => Product.fromJson(asJsonMap(data)),
    );
  }

  Future<Product> updateProduct({
    required String id,
    String? name,
    String? kind,
    double? sellPrice,
    String? categoryId,
    bool clearCategory = false,
  }) {
    return _api.patch<Product>(
      '/catalog/products/$id',
      data: {
        if (name != null) 'name': name,
        if (kind != null) 'kind': kind,
        if (sellPrice != null) 'sell_price': moneyToApi(sellPrice),
        if (clearCategory) 'category_id': null,
        if (!clearCategory && categoryId != null) 'category_id': categoryId,
      },
      parse: (data) => Product.fromJson(asJsonMap(data)),
    );
  }

  Future<void> archiveProduct(String id) {
    return _api.post<void>('/catalog/products/$id/archive');
  }

  Future<void> unarchiveProduct(String id) {
    return _api.post<void>('/catalog/products/$id/unarchive');
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

  Future<void> unarchiveRecipe(String id) {
    return _api.post<void>('/catalog/recipes/$id/unarchive');
  }
}
