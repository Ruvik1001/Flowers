import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/features/admin/domain/entities/role.dart';
import 'package:flowers/features/admin/domain/entities/staff_user.dart';

class AdminRepository {
  AdminRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Role>> listRoles() {
    return _api.get<List<Role>>(
      '/identity/roles',
      parse: (data) =>
          asJsonList(data).map((e) => Role.fromJson(asJsonMap(e))).toList(),
    );
  }

  Future<List<StaffUser>> listUsers() {
    return _api.get<List<StaffUser>>(
      '/identity/users',
      parse: (data) =>
          asJsonList(data).map((e) => StaffUser.fromJson(asJsonMap(e))).toList(),
    );
  }

  Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required List<String> roleIds,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/identity/users',
      data: {
        'email': email,
        'password': password,
        'role_ids': roleIds,
      },
      parse: asJsonMap,
    );
  }

  Future<Role> createRole({
    required String name,
    required List<String> permissions,
  }) {
    return _api.post<Role>(
      '/identity/roles',
      data: {
        'name': name,
        'permissions': permissions,
      },
      parse: (data) => Role.fromJson(asJsonMap(data)),
    );
  }
}
