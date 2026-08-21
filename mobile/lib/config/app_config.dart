class AppConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
  );

  static const String apiBaseUrl = '$backendBaseUrl/api/v1';
}
