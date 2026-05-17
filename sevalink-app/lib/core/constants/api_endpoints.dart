class ApiEndpoints {
  static const String baseUrl = 'http://localhost:8080/api';
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String forgotPassword = '$baseUrl/auth/forgot-password';
  static const String resetPassword = '$baseUrl/auth/reset-password';
  static const String refreshToken = '$baseUrl/auth/refresh';
  static const String logout = '$baseUrl/auth/logout';
  static const String me = '$baseUrl/auth/me';
}
