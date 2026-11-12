import 'package:equatable/equatable.dart';

class Role extends Equatable {
  const Role({
    required this.id,
    required this.name,
    required this.permissions,
  });

  final String id;
  final String name;
  final List<String> permissions;

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      permissions: (json['permissions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [id, name, permissions];
}
