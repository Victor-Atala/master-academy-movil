import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../services/session_storage_service.dart';

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final SessionStorageService _sessionStorage;
  static const String _tokenKey = 'jwt_auth_token';
  static const String _userKey = 'auth_user_data';

  ApiClient({
    Dio? dio,
    SessionStorageService? sessionStorage,
    FlutterSecureStorage? storage,
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage(aOptions: SessionStorageService.safeAndroidOptions),
        _sessionStorage = sessionStorage ??
            SessionStorageService(
              secureStorage: storage ?? const FlutterSecureStorage(aOptions: SessionStorageService.safeAndroidOptions),
            ) {
    _dio.options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConstants.baseUrl;
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );

    _storage.read(key: 'custom_api_base_url').then((savedUrl) {
      if (savedUrl != null && savedUrl.isNotEmpty) {
        ApiConstants.setBaseUrl(savedUrl);
        _dio.options.baseUrl = ApiConstants.baseUrl;
      }
    }).catchError((_) {});
  }

  Future<void> saveToken(String token) async {
    await _sessionStorage.saveToken(token);
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  Future<String?> getToken() async {
    final token = await _sessionStorage.getToken();
    if (token != null && token.isNotEmpty) return token;
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {}
    return null;
  }

  Future<void> clearToken() async {
    await _sessionStorage.clearToken();
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  Future<void> saveUser(String userJson) async {
    await _sessionStorage.saveUserJson(userJson);
    try {
      await _storage.write(key: _userKey, value: userJson);
    } catch (_) {}
  }

  Future<String?> getUser() async {
    final userJson = await _sessionStorage.getUserJson();
    if (userJson != null && userJson.isNotEmpty) return userJson;
    try {
      return await _storage.read(key: _userKey);
    } catch (_) {}
    return null;
  }

  Future<void> clearUser() async {
    await _sessionStorage.clearUser();
    try {
      await _storage.delete(key: _userKey);
    } catch (_) {}
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiConnectionException(
        message: 'No se pudo conectar con el servidor. Revisa tu conexión de red.',
      );
    }
    final message = error.response?.data?['message'] ??
        error.message ??
        'Error en el servidor.';
    return ApiException(message: message.toString(), statusCode: error.response?.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;
}

class ApiConnectionException implements Exception {
  final String message;
  final int? statusCode;

  ApiConnectionException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
