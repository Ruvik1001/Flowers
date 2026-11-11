import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/catalog/domain/entities/recipe_item.dart';
import 'package:flowers/features/catalog/presentation/cubit/catalog_state.dart';
import 'package:flowers/features/catalog/data/catalog_repository.dart';

class CatalogCubit extends SafeCubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogState());

  final CatalogRepository _repository;

  Future<void> load({bool includeArchived = false}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final products = await _repository.listProducts(
        includeArchived: includeArchived,
      );
      final recipes = await _repository.listRecipes(
        includeArchived: includeArchived,
      );
      emit(
        state.copyWith(
          loading: false,
          products: products,
          recipes: recipes,
          clearError: true,
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> createProduct({
    required String name,
    required String kind,
    required double sellPrice,
  }) async {
    try {
      await _repository.createProduct(
        name: name,
        kind: kind,
        sellPrice: sellPrice,
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
}
