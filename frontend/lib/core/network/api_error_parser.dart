import 'package:dio/dio.dart';
import 'package:flowers/core/l10n/labels.dart';

import '../errors/app_failure.dart';

AppFailure mapDioError(Object error) {
  if (error is AppFailure) {
    return AppFailure(
      code: error.code,
      message: Labels.errorCode(error.code, error.message),
      statusCode: error.statusCode,
      details: error.details,
    );
  }
  if (error is! DioException) {
    return const AppFailure(message: 'Неизвестная ошибка');
  }

  final response = error.response;
  final data = response?.data;

  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    if (map['code'] is String) {
      final code = map['code'] as String;
      final raw = (map['message'] as String?) ?? 'Ошибка запроса';
      return AppFailure(
        code: code,
        message: Labels.errorCode(code, raw),
        statusCode: response?.statusCode,
        details: map['details'] is Map
            ? Map<String, dynamic>.from(map['details'] as Map)
            : null,
      );
    }
    if (map['detail'] is List) {
      final details = map['detail'] as List;
      final first = details.isNotEmpty ? details.first : null;
      final msg = first is Map && first['msg'] != null
          ? 'Ошибка валидации'
          : 'Ошибка валидации';
      return AppFailure(
        code: 'validation_error',
        message: msg,
        statusCode: response?.statusCode ?? 422,
      );
    }
    if (map['status'] == 'not_ready') {
      return AppFailure(
        code: 'not_ready',
        message: Labels.errorCode('not_ready', 'Сервис не готов'),
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
    message: Labels.errorCode(null, 'Сетевая ошибка'),
    statusCode: response?.statusCode,
  );
}
