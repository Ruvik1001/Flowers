import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import 'api_error_parser.dart';

typedef RefreshCallback = Future<bool> Function();

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStorage tokenStorage,
    required RefreshCallback onRefresh,
  })  : _tokenStorage = tokenStorage,
        _onRefresh = onRefresh,
        dio = Dio(
          BaseOptions(
            baseUrl: config.apiV1,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['X-Request-Id'] ??= const Uuid().v4();
          final token = await _tokenStorage.readAccess();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isAuthPath = path.contains('/identity/auth/login') ||
              path.contains('/identity/auth/refresh');

          if (status == 401 && !isAuthPath && !_refreshing) {
            _refreshing = true;
            try {
              final ok = await _onRefresh();
              if (ok) {
                final token = await _tokenStorage.readAccess();
                final req = error.requestOptions;
                req.headers['Authorization'] = 'Bearer $token';
                final response = await dio.fetch(req);
                handler.resolve(response);
                return;
              }
            } catch (_) {
              // fall through
            } finally {
              _refreshing = false;
            }
          }
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: mapDioError(error),
              message: error.message,
            ),
          );
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;
  final RefreshCallback _onRefresh;
  bool _refreshing = false;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parse,
  }) async {
    try {
      final res = await dio.get<dynamic>(path, queryParameters: query);
      return parse != null ? parse(res.data) : res.data as T;
    } catch (e) {
      throw mapDioError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    T Function(dynamic data)? parse,
  }) async {
    try {
      final res = await dio.post<dynamic>(path, data: data);
      return parse != null ? parse(res.data) : res.data as T;
    } catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Response<dynamic>> postMultipart(
    String path, {
    required FormData formData,
  }) async {
    try {
      return await dio.post<dynamic>(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final res = await dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? <int>[];
    } catch (e) {
      throw mapDioError(e);
    }
  }
}
