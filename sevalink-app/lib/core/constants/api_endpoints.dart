import 'dart:io' show Platform;

class ApiEndpoints {
  // Change this to your PC's local IP if testing over Wi-Fi,
  // or keep 'localhost' and run: adb reverse tcp:8080 tcp:8080 for USB.
  static const String _localIp = '192.168.43.189';

  static String get baseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://$_localIp:8080/api';
      }
    } catch (e) {
      // Web or other platforms — localhost works fine
    }
    return 'http://localhost:8080/api';
  }

  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get resetPassword => '$baseUrl/auth/reset-password';
  static String get refreshToken => '$baseUrl/auth/refresh';
  static String get logout => '$baseUrl/auth/logout';
  static String get me => '$baseUrl/auth/me';
  static String get clientDashboard => '$baseUrl/client/dashboard';
}