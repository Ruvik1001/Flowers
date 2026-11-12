import 'package:flowers/core/auth/token_storage.dart';
import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/features/auth/domain/entities/staff_user.dart';
import 'package:flowers/features/auth/domain/entities/token_pair.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required TokenStorage tokenStorage,
  })  : _api = api,
        _tokenStorage = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<bool> hasStoredSession() async {
    final access = await _tokenStorage.readAccess();
    return access != null && access.isNotEmpty;
  }

  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final pair = await _api.post<TokenPair>(
      '/identity/auth/login',
      data: {'email': email, 'password': password},
      parse: (data) => TokenPair.fromJson(asJsonMap(data)),
    );
    await _tokenStorage.saveTokens(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
    );
    return pair;
  }

  Future<StaffUser> me() {
    return _api.get<StaffUser>(
      '/identity/auth/me',
      parse: (data) => StaffUser.fromJson(asJsonMap(data)),
    );
  }

  Future<bool> refreshSession() async {
    final refresh = await _tokenStorage.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      await _tokenStorage.clear();
      return false;
    }
    try {
      final pair = await _api.post<TokenPair>(
        '/identity/auth/refresh',
        data: {'refresh_token': refresh},
        parse: (data) => TokenPair.fromJson(asJsonMap(data)),
      );
      await _tokenStorage.saveTokens(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
      return pair.accessToken.isNotEmpty;
    } catch (_) {
      await _tokenStorage.clear();
      return false;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
  }
}
