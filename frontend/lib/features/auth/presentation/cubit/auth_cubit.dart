import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/auth/data/auth_repository.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_state.dart';

class AuthCubit extends SafeCubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthUnknown());

  final AuthRepository _repository;

  Future<void> bootstrap() async {
    emit(const AuthUnknown());
    try {
      final hasSession = await _repository.hasStoredSession();
      if (!hasSession) {
        emit(const Unauthenticated());
        return;
      }
      final user = await _repository.me();
      emit(Authenticated(user));
    } on AppFailure {
      final refreshed = await _repository.refreshSession();
      if (!refreshed) {
        emit(const Unauthenticated());
        return;
      }
      try {
        final user = await _repository.me();
        emit(Authenticated(user));
      } on AppFailure catch (err) {
        emit(AuthFailure(err.message));
        emit(const Unauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(const Unauthenticated());
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      await _repository.login(email: email, password: password);
      final user = await _repository.me();
      emit(Authenticated(user));
    } on AppFailure catch (e) {
      emit(AuthFailure(e.message));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const Unauthenticated());
  }

  Future<void> refreshSession() async {
    try {
      final ok = await _repository.refreshSession();
      if (!ok) {
        emit(const Unauthenticated());
        return;
      }
      final user = await _repository.me();
      emit(Authenticated(user));
    } on AppFailure catch (e) {
      emit(AuthFailure(e.message));
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(const Unauthenticated());
    }
  }
}
