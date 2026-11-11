import 'package:equatable/equatable.dart';

class StaffUser extends Equatable {
  const StaffUser({
    required this.id,
    required this.email,
    required this.isAdmin,
    required this.roles,
    required this.permissions,
    required this.objectScopes,
  });

  final String id;
  final String email;
  final bool isAdmin;
  final List<String> roles;
  final List<String> permissions;
  final Map<String, List<String>> objectScopes;

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final scopesRaw = json['object_scopes'];
    final scopes = <String, List<String>>{};
    if (scopesRaw is Map) {
      for (final entry in scopesRaw.entries) {
        final value = entry.value;
        scopes[entry.key.toString()] = value is List
            ? value.map((e) => e.toString()).toList()
            : const <String>[];
      }
    }

    return StaffUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isAdmin: json['is_admin'] == true,
      roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      permissions:
          (json['permissions'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      objectScopes: scopes,
    );
  }

  @override
  List<Object?> get props =>
      [id, email, isAdmin, roles, permissions, objectScopes];
}
