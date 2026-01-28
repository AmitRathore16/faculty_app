import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late final Dio _dio;
  
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await StorageService.getSecure(AppConfig.authTokenKey);

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        // onError: (error, handler) async {
        //   if (error.response?.statusCode == 401) {
        //     // Token expired - clear auth data
        //     await StorageService.deleteSecure(AppConfig.authTokenKey);
        //     await StorageService.remove(AppConfig.userDataKey);
        //     await StorageService.remove(AppConfig.userRoleKey);
        //   }
        //   return handler.next(error);
        // },
        onError: (error, handler) async {
          final status = error.response?.statusCode;

          // ✅ only logout on 401 for protected endpoints
          if (status == 401) {
            final path = error.requestOptions.path;

            // ❌ do NOT logout for these
            final ignorePaths = [
              '/api/auth/login-student',
              '/api/auth/signup-student',
              '/api/auth/forgot-password',
            ];

            final shouldIgnore = ignorePaths.any((p) => path.contains(p));

            if (!shouldIgnore) {
              // ✅ only logout if token exists but still 401
              final token = await StorageService.getSecure(AppConfig.authTokenKey);

              if (token != null && token.isNotEmpty) {
                await StorageService.deleteSecure(AppConfig.authTokenKey);
                await StorageService.remove(AppConfig.userDataKey);
                await StorageService.remove(AppConfig.userRoleKey);
              }
            }
          }

          return handler.next(error);
        },

      ),
    );
    
    // Add logging interceptor in debug mode
    _dio.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
  }
  
  Dio get dio => _dio;
  
  // Generic GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  // Generic POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  // Generic PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  // Generic DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  // Upload file
  Future<Response<T>> uploadFile<T>(
    String path, {
    required FormData formData,
    void Function(int, int)? onSendProgress,
  }) async {
    return _dio.post<T>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );
  }
}
