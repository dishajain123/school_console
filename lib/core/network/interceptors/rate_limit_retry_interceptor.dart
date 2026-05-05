import 'package:dio/dio.dart';

/// Retries requests rejected with HTTP 429 (rate limit), using [Retry-After] when present.
///
/// The backend raises authenticated SPA budgets; this covers bursts and shared NATs.
class RateLimitRetryInterceptor extends Interceptor {
  RateLimitRetryInterceptor(
    this._dio, {
    this.maxAttempts = 4,
  });

  final Dio _dio;
  final int maxAttempts;

  static const _kAttempts = '_rate_limit_retry_count';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 429) {
      handler.next(err);
      return;
    }
    final options = err.requestOptions;
    final done = (options.extra[_kAttempts] as int?) ?? 0;
    if (done >= maxAttempts) {
      handler.next(err);
      return;
    }
    final header = err.response?.headers.value('retry-after') ??
        err.response?.headers.value('Retry-After');
    var seconds = int.tryParse(header?.trim() ?? '') ?? (1 << done);
    if (seconds < 1) seconds = 1;
    if (seconds > 60) seconds = 60;
    await Future<void>.delayed(Duration(seconds: seconds));
    options.extra[_kAttempts] = done + 1;
    try {
      final response = await _dio.fetch<void>(options);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(err);
      }
    }
  }
}
