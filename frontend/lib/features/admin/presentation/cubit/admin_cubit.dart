import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/admin/data/admin_repository.dart';
import 'package:flowers/features/admin/domain/entities/staff_user.dart';
import 'package:flowers/features/admin/presentation/cubit/admin_state.dart';

class AdminCubit extends SafeCubit<AdminState> {
  AdminCubit(this._repository) : super(const AdminState());

  final AdminRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final roles = await _repository.listRoles();
      var users = <StaffUser>[];
      try {
        users = await _repository.listUsers();
      } catch (_) {
        // Non-admin may lack users list permission — roles still useful.
      }
      emit(
        state.copyWith(
          loading: false,
          roles: roles,
          users: users,
          clearError: true,
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> createUser({
    required String email,
    required String password,
    required List<String> roleIds,
  }) async {
    try {
      final created = await _repository.createUser(
        email: email,
        password: password,
        roleIds: roleIds,
      );
      await load();
      emit(
        state.copyWith(
          lastMessage: 'Пользователь ${created['email'] ?? email} создан',
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }

  Future<void> createRole({
    required String name,
    required List<String> permissions,
  }) async {
    try {
      await _repository.createRole(name: name, permissions: permissions);
      await load();
      emit(state.copyWith(lastMessage: 'Роль создана'));
    } on AppFailure catch (e) {
      emit(state.copyWith(error: e.message));
      rethrow;
    }
  }
}
