import 'package:equatable/equatable.dart';
import 'package:flowers/features/catalog/domain/entities/category.dart';
import 'package:flowers/features/catalog/domain/entities/product.dart';
import 'package:flowers/features/catalog/domain/entities/recipe.dart';

class CatalogState extends Equatable {
  const CatalogState({
    this.loading = false,
    this.products = const [],
    this.recipes = const [],
    this.categories = const [],
    this.includeArchived = false,
    this.error,
  });

  final bool loading;
  final List<Product> products;
  final List<Recipe> recipes;
  final List<Category> categories;
  final bool includeArchived;
  final String? error;

  CatalogState copyWith({
    bool? loading,
    List<Product>? products,
    List<Recipe>? recipes,
    List<Category>? categories,
    bool? includeArchived,
    String? error,
    bool clearError = false,
  }) {
    return CatalogState(
      loading: loading ?? this.loading,
      products: products ?? this.products,
      recipes: recipes ?? this.recipes,
      categories: categories ?? this.categories,
      includeArchived: includeArchived ?? this.includeArchived,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [loading, products, recipes, categories, includeArchived, error];
}
