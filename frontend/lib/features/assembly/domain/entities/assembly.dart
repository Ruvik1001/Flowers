import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';

class AssemblyComponent extends Equatable {
  const AssemblyComponent({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final double quantity;

  factory AssemblyComponent.fromJson(Map<String, dynamic> json) {
    return AssemblyComponent(
      productId: json['product_id']?.toString() ?? '',
      quantity: parseMoney(json['quantity']),
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': moneyToApi(quantity),
      };

  @override
  List<Object?> get props => [productId, quantity];
}

class Assembly extends Equatable {
  const Assembly({
    required this.id,
    required this.bouquetProductId,
    required this.quantity,
    required this.kind,
    required this.components,
    this.recipeId,
    this.cost = 0,
  });

  final String id;
  final String bouquetProductId;
  final double quantity;
  final String kind;
  final List<AssemblyComponent> components;
  final String? recipeId;
  final double cost;

  factory Assembly.fromJson(Map<String, dynamic> json) {
    return Assembly(
      id: json['id']?.toString() ?? '',
      bouquetProductId: json['bouquet_product_id']?.toString() ?? '',
      quantity: parseMoney(json['quantity']),
      kind: json['kind']?.toString() ?? '',
      recipeId: json['recipe_id']?.toString(),
      cost: parseMoney(json['cost']),
      components: (json['components'] as List?)
              ?.map((e) => AssemblyComponent.fromJson(asJsonMap(e)))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props =>
      [id, bouquetProductId, quantity, kind, components, recipeId, cost];
}
