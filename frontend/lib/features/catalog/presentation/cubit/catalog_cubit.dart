import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/catalog/data/catalog_repository.dart';
import 'package:flowers/features/catalog/domain/entities/recipe_item.dart';
import 'package:flowers/features/catalog/presentation/cubit/catalog_state.dart';

class CatalogCubit extends SafeCubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogState());

  final CatalogRepository _repository;

  Future<void> load({bool? includeArchived}) async {
    final showArchived = includeArchived ?? state.includeArchived;
    emit(
      state.copyWith(
        loading: true,
        includeArchived: showArchived,
        clearError: true,
      ),
    );
    try {
      final products = await _repository.listProducts(
        includeArchived: showArchived,
      );
      final recipes = await _repository.listRecipes(
        includeArchived: showArchived,
      );
      final categories = await _repository.listCategories(
        includeArchived: showArchived,
      );
      emit(
        state.copyWith(
          loading: false,
          products: products,
          recipes: recipes,
          categories: categories,
          clearError: true,
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> createCategory({required String name}) async {
    try {
      await _repository.createCategory(name: name);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> archiveCategory(String id) async {
    try {
      await _repository.archiveCategory(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> unarchiveCategory(String id) async {
    try {
      await _repository.unarchiveCategory(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> createProduct({
    required String name,
    required String kind,
    required double sellPrice,
    String? categoryId,
  }) async {
    try {
      await _repository.createProduct(
        name: name,
        kind: kind,
        sellPrice: sellPrice,
        categoryId: categoryId,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> updateProduct({
    required String id,
    String? name,
    String? kind,
    double? sellPrice,
    String? categoryId,
    bool clearCategory = false,
  }) async {
    try {
      await _repository.updateProduct(
        id: id,
        name: name,
        kind: kind,
        sellPrice: sellPrice,
        categoryId: categoryId,
        clearCategory: clearCategory,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> archiveProduct(String id) async {
    try {
      await _repository.archiveProduct(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> unarchiveProduct(String id) async {
    try {
      await _repository.unarchiveProduct(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> createRecipe({
    required String bouquetId,
    required List<RecipeItem> items,
  }) async {
    try {
      await _repository.createRecipe(bouquetId: bouquetId, items: items);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> archiveRecipe(String id) async {
    try {
      await _repository.archiveRecipe(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> unarchiveRecipe(String id) async {
    try {
      await _repository.unarchiveRecipe(id);
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }
}
