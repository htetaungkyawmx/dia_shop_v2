/// Build-time configuration.
///
///   flutter run -d chrome --dart-define=API_BASE_URL=https://api.diashop.com
class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String get apiRoot => '$apiBaseUrl/api/v1';
}
