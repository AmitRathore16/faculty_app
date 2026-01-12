class AppConfig {
  AppConfig._();
  
  static const String appName = 'Faculty Pedia';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String baseUrl = 'https://faculty-server-h5i1.onrender.com';
  static const String baseUrl1 = 'https://faculty-pedia-backend.onrender.com';
  static const String baseUrl2 = 'http://localhost:5001';
  static const String apiPrefix = '/api';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Storage Keys
  static const String authTokenKey = 'faculty-pedia-auth-token';
  static const String userDataKey = 'faculty-pedia-user-data';
  static const String userRoleKey = 'user-role';
  static const String themeKey = 'theme-mode';
  static const String offlineResultsKey = 'faculty-pedia-offline-results';
  
  // Razorpay (placeholder - should be fetched from backend)
  static const String razorpayKeyId = '';
  
  // Feature Flags
  static const bool enableBiometricAuth = true;
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  static const bool enableDarkMode = true;
}
