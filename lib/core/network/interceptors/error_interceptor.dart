import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ErrorInterceptor extends Interceptor {
  String _safePath(RequestOptions o) => o.path.isEmpty ? o.uri.toString() : o.path;

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

    if (err.response?.statusCode == 401) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: err.error,
          message:
              'Session expired or unauthorized. Please login again.',
        ),
      );
      return;
    }
    handler.next(err);
  }
}
