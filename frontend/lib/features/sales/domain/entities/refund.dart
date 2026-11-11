import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class Refund extends Equatable {
  const Refund({
    required this.id,
    required this.amount,
    required this.kind,
  });

  final String id;
  final double amount;
  final String kind;

  factory Refund.fromJson(Map<String, dynamic> json) {
    return Refund(
      id: json['id']?.toString() ?? '',
      amount: parseMoney(json['amount']),
      kind: json['kind']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [id, amount, kind];
}
