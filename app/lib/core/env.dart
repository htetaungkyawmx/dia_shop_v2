/// Build-time configuration.
///
/// Override per environment without touching the code:
///   flutter run --dart-define=API_BASE_URL=https://api.diashop.com
class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// OAuth client id for Google Sign-In. Empty disables the Google button.
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static String get apiRoot => '$apiBaseUrl/api/v1';

  static bool get hasGoogleSignIn => googleClientId.isNotEmpty;
}
