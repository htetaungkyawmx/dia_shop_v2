import 'package:shared_preferences/shared_preferences.dart';

/// The admin panel runs in a browser, so tokens live in local storage. The
/// access token is short-lived and the refresh token rotates on every use.
class TokenStore {
  TokenStore._(this._prefs);

  static const _accessKey = 'dia_admin_access_token';
  static const _refreshKey = 'dia_admin_refresh_token';

  final SharedPreferences _prefs;

  static Future<TokenStore> create() async =>
      TokenStore._(await SharedPreferences.getInstance());

  String? get accessToken => _prefs.getString(_accessKey);

  String? get refreshToken => _prefs.getString(_refreshKey);

  bool get hasSession => refreshToken != null;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    await _prefs.setString(_accessKey, accessToken);
    await _prefs.setString(_refreshKey, refreshToken);
  }

  Future<void> clear() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }
}
