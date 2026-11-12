import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class RecipeItem extends Equatable {
  const RecipeItem({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final double quantity;

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
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
