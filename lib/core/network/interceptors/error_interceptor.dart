import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Normalizes connection and HTTP errors for UI; does **not** clear tokens or logout
/// (that stays in [AuthInterceptor] after refresh failure).
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor();

  String _safePath(RequestOptions o) =>
      o.path.isEmpty ? o.uri.toString() : o.path;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.cancel) {
      handler.next(err);
      return;
    }

    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      final isWeb = kIsWeb;
      final hint = isWeb
          ? 'If backend is running, also check browser CORS / API base URL.'
          : 'Please ensure backend and database are running.';
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          type: err.type,
          error: err.error,
          message:
              'Connection failed for ${_safePath(err.requestOptions)}. $hint',
        ),
      );
      return;
    }

    if (err.response == null) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          type: err.type,
          error: err.error,
          message:
              'Request failed for ${_safePath(err.requestOptions)}. ${err.message ?? 'No response received.'}',
        ),
      );
      return;
    }

    final statusCode = err.response?.statusCode;

    if (statusCode == 403) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: err.error,
          message:
              'You don\'t have permission for this action. '
              'Contact an administrator if you need access.',
        ),
      );
      return;
    }

    if (statusCode == 401) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: err.error,
          message: 'Session expired or unauthorized. Please sign in again.',
        ),
      );
      return;
    }

    handler.next(err);
  }
}
