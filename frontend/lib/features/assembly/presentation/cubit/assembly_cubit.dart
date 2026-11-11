import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';
import 'package:flowers/features/assembly/presentation/cubit/assembly_state.dart';
import 'package:flowers/features/assembly/data/assembly_repository.dart';

class AssemblyCubit extends SafeCubit<AssemblyState> {
  AssemblyCubit(this._repository) : super(const AssemblyState());

  final AssemblyRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final assemblies = await _repository.listAssemblies();
      emit(
        state.copyWith(
          loading: false,
          assemblies: assemblies,
          clearError: true,
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> create({
    required String bouquetProductId,
    required double quantity,
    required String kind,
    required List<AssemblyComponent> components,
    String? recipeId,
  }) async {
    try {
      await _repository.createAssembly(
        bouquetProductId: bouquetProductId,
        quantity: quantity,
        kind: kind,
        components: components,
        recipeId: recipeId,
      );
      await load();
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }
}
