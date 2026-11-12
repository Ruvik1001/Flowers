import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.kind,
    required this.sellPrice,
    required this.archived,
    this.categoryId,
  });

  final String id;
  final String name;
  final String kind;
  final double sellPrice;
  final bool archived;
  final String? categoryId;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      sellPrice: parseMoney(json['sell_price']),
      archived: json['archived'] == true,
      categoryId: json['category_id']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, kind, sellPrice, archived, categoryId];
}
