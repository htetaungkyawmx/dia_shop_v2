import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the auth tokens.
///
/// Mobile uses the platform keystore. On the web there is no equivalent, so
/// tokens live in local storage — which is why the access token is short-lived
/// and the refresh token is rotated on every use.
class TokenStore {
  TokenStore._(this._secure, this._prefs);

  static const _accessKey = 'dia_access_token';
  static const _refreshKey = 'dia_refresh_token';

  final FlutterSecureStorage? _secure;
  final SharedPreferences _prefs;

  String? _accessToken;
  String? _refreshToken;

  static Future<TokenStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    final secure = kIsWeb
        ? null
        : const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
    final store = TokenStore._(secure, prefs);
    await store._load();
    return store;
  }

  Future<void> _load() async {
    if (_secure != null) {
      _accessToken = await _secure.read(key: _accessKey);
      _refreshToken = await _secure.read(key: _refreshKey);
    } else {
      _accessToken = _prefs.getString(_accessKey);
      _refreshToken = _prefs.getString(_refreshKey);
    }
  }

  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  bool get hasSession => _refreshToken != null;

  Future<void> save(
      {required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (_secure != null) {
      await _secure.write(key: _accessKey, value: accessToken);
      await _secure.write(key: _refreshKey, value: refreshToken);
    } else {
      await _prefs.setString(_accessKey, accessToken);
      await _prefs.setString(_refreshKey, refreshToken);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    if (_secure != null) {
      await _secure.delete(key: _accessKey);
      await _secure.delete(key: _refreshKey);
    } else {
      await _prefs.remove(_accessKey);
      await _prefs.remove(_refreshKey);
    }
  }
}
