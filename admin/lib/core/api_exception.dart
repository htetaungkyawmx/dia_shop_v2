import 'package:dio/dio.dart';

/// A failure that already carries a message worth showing to the user.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code = 'UNKNOWN',
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final String code;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isInsufficientBalance => code == 'INSUFFICIENT_BALANCE';
  bool get isOutOfStock => code == 'OUT_OF_STOCK';
  bool get isMaintenance => code == 'MAINTENANCE';

  /// Turns any Dio failure into something with a sentence a person can read.
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return ApiException(
            code: 'TIMEOUT',
            message: 'The server took too long to respond. Please try again.',
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          return ApiException(
            code: 'NO_CONNECTION',
            message: 'Cannot reach the server. Check your internet connection.',
          );
        case DioExceptionType.cancel:
          return ApiException(code: 'CANCELLED', message: 'Request cancelled.');
        case DioExceptionType.badCertificate:
          return ApiException(
            code: 'BAD_CERTIFICATE',
            message: 'The server certificate could not be verified.',
          );
        case DioExceptionType.badResponse:
          return _fromResponse(error.response);
      }
    }
    return ApiException(message: 'Something went wrong. Please try again.');
  }

  static ApiException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final body = response?.data;

    if (body is Map) {
      final rawFields = body['fieldErrors'];
      return ApiException(
        code: (body['code'] as String?) ?? 'ERROR',
        message: (body['message'] as String?) ?? _defaultMessageFor(status),
        statusCode: status,
        fieldErrors: rawFields is Map
            ? rawFields.map((key, value) => MapEntry('$key', '$value'))
            : const {},
      );
    }
    return ApiException(
      code: 'ERROR',
      message: _defaultMessageFor(status),
      statusCode: status,
    );
  }

  static String _defaultMessageFor(int? status) {
    return switch (status) {
      401 => 'Please sign in to continue.',
      403 => 'You do not have access to this.',
      404 => 'We could not find what you were looking for.',
      409 => 'That action conflicts with the current state. Please refresh.',
      final int code when code >= 500 =>
        'The server had a problem. Please try again shortly.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  @override
  String toString() => 'ApiException($code): $message';
}
