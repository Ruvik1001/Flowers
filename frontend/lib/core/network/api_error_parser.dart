import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

AppFailure mapDioError(Object error) {
  if (error is AppFailure) return error;
  if (error is! DioException) {
    return AppFailure(message: error.toString());
  }

  final response = error.response;
  final data = response?.data;

  if (data is Map<String, dynamic>) {
    if (data['code'] is String) {
      return AppFailure(
        code: data['code'] as String,
        message: (data['message'] as String?) ?? 'Ошибка запроса',
        statusCode: response?.statusCode,
        details: data['details'] is Map<String, dynamic>
            ? data['details'] as Map<String, dynamic>
            : null,
      );
    }
    if (data['detail'] is List) {
      final details = data['detail'] as List;
      final first = details.isNotEmpty ? details.first : null;
      final msg = first is Map && first['msg'] != null
          ? first['msg'].toString()
          : 'Ошибка валидации';
      return AppFailure(
        code: 'validation_error',
        message: msg,
        statusCode: response?.statusCode ?? 422,
      );
    }
    if (data['status'] == 'not_ready') {
      return AppFailure(
        code: 'not_ready',
        message: (data['detail'] as String?) ?? 'Сервис не готов',
        statusCode: response?.statusCode ?? 503,
      );
    }
  }

  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return const AppFailure(code: 'timeout', message: 'Таймаут запроса');
  }
  if (error.type == DioExceptionType.connectionError) {
    return const AppFailure(
      code: 'connection_error',
      message: 'Нет связи с сервером',
    );
  }

  return AppFailure(
    message: error.message ?? 'Сетевая ошибка',
    statusCode: response?.statusCode,
  );
}
