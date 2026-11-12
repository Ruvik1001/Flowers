import 'package:equatable/equatable.dart';

class StaffUser extends Equatable {
  const StaffUser({
    required this.id,
    required this.email,
    required this.isAdmin,
    required this.isActive,
    this.roleIds = const [],
    this.roles = const [],
  });

  final String id;
  final String email;
  final bool isAdmin;
  final bool isActive;
  final List<String> roleIds;
  final List<String> roles;

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isAdmin: json['is_admin'] == true,
      isActive: json['is_active'] != false,
      roleIds: (json['role_ids'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      roles:
          (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  @override
  List<Object?> get props => [id, email, isAdmin, isActive, roleIds, roles];
}
