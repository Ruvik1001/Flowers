import 'package:equatable/equatable.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.archived,
  });

  final String id;
  final String name;
  final bool archived;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      archived: json['archived'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, archived];
}
