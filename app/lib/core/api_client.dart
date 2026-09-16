import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'env.dart';
import 'token_store.dart';

/// HTTP client for the Game Store API.
///
/// Attaches the access token, and on a 401 refreshes once and replays the
/// request. Concurrent 401s share a single refresh so a screen with several
/// parallel requests does not burn the refresh token more than once.
class ApiClient {
  ApiClient(this._tokens, {required this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiRoot,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
        // Let the interceptor decide what counts as an error.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.accessToken;
          if (token != null && options.extra['skipAuth'] != true) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuthError = error.response?.statusCode == 401;
          final canRetry = error.requestOptions.extra['retried'] != true &&
              error.requestOptions.extra['skipAuth'] != true;

          if (!isAuthError || !canRetry || !_tokens.hasSession) {
            return handler.next(error);
          }

          final refreshed = await _refreshOnce();
          if (!refreshed) {
            await onSessionExpired();
            return handler.next(error);
          }

          try {
            final options = error.requestOptions;
            options.extra['retried'] = true;
            options.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
            final response = await _dio.fetch<dynamic>(options);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );
  }

  final TokenStore _tokens;
  final Future<void> Function() onSessionExpired;

  late final Dio _dio;
  Future<bool>? _pendingRefresh;

  Future<bool> _refreshOnce() {
    // Every caller that hits a 401 at the same time awaits this one future.
    return _pendingRefresh ??= _performRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _tokens.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true, 'retried': true}),
      );
      final data = response.data!;
      await _tokens.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await _tokens.clear();
      return false;
    }
  }

  Future<T> get<T>(String path,
      {Map<String, dynamic>? query, bool auth = true}) {
    return _run(() => _dio.get<T>(path,
        queryParameters: _clean(query), options: _options(auth)));
  }

  Future<T> post<T>(String path, {Object? body, bool auth = true}) {
    return _run(() => _dio.post<T>(path, data: body, options: _options(auth)));
  }

  Future<T> put<T>(String path, {Object? body, bool auth = true}) {
    return _run(() => _dio.put<T>(path, data: body, options: _options(auth)));
  }

  Future<T> patch<T>(String path, {Object? body, bool auth = true}) {
    return _run(() => _dio.patch<T>(path, data: body, options: _options(auth)));
  }

  Future<T> delete<T>(String path, {Object? body, bool auth = true}) {
    return _run(
        () => _dio.delete<T>(path, data: body, options: _options(auth)));
  }

  Future<T> upload<T>(String path,
      {required MultipartFile file, String field = 'file'}) {
    return _run(() => _dio.post<T>(
          path,
          data: FormData.fromMap({field: file}),
          options: _options(true),
        ));
  }

  Options _options(bool auth) => Options(extra: {'skipAuth': !auth});

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null && value != '') cleaned[key] = value;
    });
    return cleaned;
  }

  Future<T> _run<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } catch (error) {
      throw ApiException.from(error);
    }
  }
}
