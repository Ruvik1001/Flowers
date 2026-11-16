import 'package:equatable/equatable.dart';

class InventoryFolder extends Equatable {
  const InventoryFolder({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.archived = false,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool archived;

  factory InventoryFolder.fromJson(Map<String, dynamic> json) {
    return InventoryFolder(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      archived: json['archived'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, sortOrder, archived];
}
