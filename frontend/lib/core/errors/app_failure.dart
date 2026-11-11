import 'package:equatable/equatable.dart';

class AppFailure extends Equatable implements Exception {
  const AppFailure({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  @override
  List<Object?> get props => [message, code, statusCode, details];

  @override
  String toString() => 'AppFailure($statusCode, $code, $message)';
}
