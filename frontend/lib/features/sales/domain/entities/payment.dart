import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class Payment extends Equatable {
  const Payment({
    required this.method,
    required this.amount,
  });

  final String method;
  final double amount;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      method: json['method']?.toString() ?? '',
      amount: parseMoney(json['amount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'method': method,
        'amount': moneyToApi(amount),
      };

  @override
  List<Object?> get props => [method, amount];
}
