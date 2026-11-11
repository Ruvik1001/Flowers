import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class WriteOff extends Equatable {
  const WriteOff({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.reason,
    required this.photoIds,
  });

  final String id;
  final String productId;
  final double quantity;
  final String reason;
  final List<String> photoIds;

  factory WriteOff.fromJson(Map<String, dynamic> json) {
    return WriteOff(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: parseMoney(json['quantity']),
      reason: json['reason']?.toString() ?? '',
      photoIds: (json['photo_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [id, productId, quantity, reason, photoIds];
}
