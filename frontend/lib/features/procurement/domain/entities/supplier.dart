import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.archived = false,
  });

  final String id;
  final String name;
  final String? phone;
  final bool archived;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      archived: json['archived'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, archived];
}
