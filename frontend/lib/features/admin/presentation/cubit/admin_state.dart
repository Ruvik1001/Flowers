import 'package:equatable/equatable.dart';
import 'package:flowers/features/admin/domain/entities/role.dart';
import 'package:flowers/features/admin/domain/entities/staff_user.dart';

class AdminState extends Equatable {
  const AdminState({
    this.loading = false,
    this.roles = const [],
    this.users = const [],
    this.error,
    this.lastMessage,
  });

  final bool loading;
  final List<Role> roles;
  final List<StaffUser> users;
  final String? error;
  final String? lastMessage;

  AdminState copyWith({
    bool? loading,
    List<Role>? roles,
    List<StaffUser>? users,
    String? error,
    String? lastMessage,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return AdminState(
      loading: loading ?? this.loading,
      roles: roles ?? this.roles,
      users: users ?? this.users,
      error: clearError ? null : (error ?? this.error),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }

  @override
  List<Object?> get props => [loading, roles, users, error, lastMessage];
}
