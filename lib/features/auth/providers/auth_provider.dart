import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/models/student_model.dart';
import '../../../shared/models/user_model.dart';

/// =======================
/// Auth State (STUDENT ONLY)
/// =======================
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final User? user;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    User? user,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }

  bool get isStudent => user is Student;
  Student? get student => user is Student ? user as Student : null;
}

/// =======================
/// Auth Notifier
/// =======================
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;

  AuthNotifier(this._apiService) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);

    try {
      final token = await StorageService.getSecure(AppConfig.authTokenKey);
      final userDataJson = StorageService.getString(AppConfig.userDataKey);

      if (token != null &&
          token.isNotEmpty &&
          userDataJson != null &&
          userDataJson.isNotEmpty) {
        final userData = json.decode(userDataJson);
        final user = Student.fromJson(userData);

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          user: user,
        );
      } else {
        state = state.copyWith(isAuthenticated: false, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// =======================
  /// LOGIN (STUDENT ONLY)
  /// =======================
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.post(
        '/api/auth/login-student',
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data as Map<String, dynamic>;

      final token = data['TOKEN'] ?? data['token'];
      if (token == null) throw Exception('No token received');

      final userData = data['user'] ?? data['student'];
      if (userData == null) throw Exception('No user data received');

      await StorageService.setSecure(AppConfig.authTokenKey, token);
      await StorageService.setString(AppConfig.userDataKey, json.encode(userData));
      await StorageService.setString(AppConfig.userRoleKey, 'student');

      final user = Student.fromJson(userData);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: user,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  /// =======================
  /// ✅ Upload image to /api/upload
  /// returns uploaded url/path
  /// =======================
  Future<String?> _uploadStudentImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final fileSize = await imageFile.length();

      print("🟡 [UPLOAD] Starting upload...");
      print("🟡 [UPLOAD] File: ${imageFile.path}");
      print("🟡 [UPLOAD] Filename: $fileName");
      print("🟡 [UPLOAD] Size: $fileSize bytes");

      final form = FormData.fromMap({
        // ✅ must match multer: uploadGenericImage.single("image")
        "image": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _apiService.post(
        '/api/upload/image',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );

      print("✅ [UPLOAD] Response status: ${response.statusCode}");
      print("✅ [UPLOAD] Response data: ${response.data}");

      final data = response.data as Map<String, dynamic>;

      // ✅ YOUR BACKEND RETURNS imageUrl
      final String? url = data['imageUrl'];

      print("✅ [UPLOAD] Extracted imageUrl: $url");

      return url;
    } catch (e) {
      print("❌ [UPLOAD] Failed: $e");
      return null;
    }
  }


  /// =======================
  /// SIGNUP (STUDENT ONLY)
  /// =======================
  Future<bool> signupStudent({
    required String name,
    required String username,
    required String email,
    required String password,
    required String mobileNumber,
    required String specialization,
    required String academicClass,
    File? imageFile,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      String? imageUrl;

      // ✅ upload first
      if (imageFile != null) {
        imageUrl = await _uploadStudentImage(imageFile);

        if (imageUrl == null || imageUrl.isEmpty) {
          // image is optional — so continue signup without it
          imageUrl = null;
        }
      }

      final response = await _apiService.post(
        '/api/auth/signup-student',
        data: {
          'name': name.trim(),
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          'mobileNumber': mobileNumber.trim(),
          'specialization': specialization,
          'class': academicClass,
          if (imageUrl != null) 'image': imageUrl, // ✅ now it's a string URL
        },
      );

      // backend signupStudent returns: { student: ..., TOKEN: ... }
      final data = response.data as Map<String, dynamic>;
      final token = data['TOKEN'] ?? data['token'];
      final userData = data['student'] ?? data['user'];

      if (token != null && userData != null) {
        await StorageService.setSecure(AppConfig.authTokenKey, token);
        await StorageService.setString(AppConfig.userDataKey, json.encode(userData));
        await StorageService.setString(AppConfig.userRoleKey, 'student');

        final user = Student.fromJson(userData);

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          user: user,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _apiService.post(
        '/api/auth/forgot-password',
        data: {'email': email.trim()},
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.deleteSecure(AppConfig.authTokenKey);
    await StorageService.remove(AppConfig.userDataKey);
    await StorageService.remove(AppConfig.userRoleKey);

    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  String _getErrorMessage(dynamic error) {
    // Dio error
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;

      // If backend sends JSON with message
      if (data is Map<String, dynamic>) {
        final backendMessage = (data['message'] ?? '').toString().toLowerCase();

        // ✅ uniqueness cases
        if (backendMessage.contains('already exists')) {
          if (backendMessage.contains('email')) {
            return 'Email already registered. Please login.';
          }
          if (backendMessage.contains('mobile')) {
            return 'Mobile number already registered. Please login.';
          }
          if (backendMessage.contains('username')) {
            return 'Username already taken. Try a different username.';
          }

          // if backend doesn't specify which one
          return 'Email / mobile / username already exists.';
        }

        // ✅ validation errors
        if (backendMessage.contains('validation')) {
          final errors = data['errors'];
          if (errors is List && errors.isNotEmpty) {
            final first = errors.first;
            if (first is Map && first['msg'] != null) {
              return first['msg'].toString();
            }
          }
          return 'Invalid signup data. Please check inputs.';
        }

        if (data['message'] != null) return data['message'].toString();
      }

      // fallback based on status code
      if (status == 400) return 'Invalid signup data.';
      if (status == 401) return 'Invalid email or password.';
      if (status == 403) return 'Access denied.';
      if (status == 409) return 'User already exists.';
      if (status == 500) return 'Server error. Try again later.';
    }

    // normal exceptions
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Network error. Please check your internet connection.';
    }

    return 'Request failed. Please try again.';
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Providers
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiServiceProvider));
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});
