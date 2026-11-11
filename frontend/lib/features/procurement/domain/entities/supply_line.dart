import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class SupplyLine extends Equatable {
  const SupplyLine({
    required this.productId,
    required this.quantity,
    required this.ordered,
    required this.unitCost,
    required this.accepted,
  });

  final String productId;
  final double quantity;
  final double ordered;
  final double unitCost;
  final double accepted;

  factory SupplyLine.fromJson(Map<String, dynamic> json) {
    final ordered = parseMoney(json['ordered'] ?? json['quantity']);
    return SupplyLine(
      productId: json['product_id']?.toString() ?? '',
      quantity: parseMoney(json['quantity'] ?? json['ordered']),
      ordered: ordered,
      unitCost: parseMoney(json['unit_cost']),
      accepted: parseMoney(json['accepted']),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'product_id': productId,
        'quantity': moneyToApi(quantity),
        'unit_cost': moneyToApi(unitCost),
      };

  @override
  List<Object?> get props =>
      [productId, quantity, ordered, unitCost, accepted];
}
