import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorage _storage;
  bool _isRefreshing = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicPath(options.path)) {
      handler.next(options);
      return;
    }

    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      handler.next(err);
      return;
    }

    final requestPath = err.requestOptions.path;
    if (_isPublicPath(requestPath) || requestPath == ApiConstants.refresh) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        await _storage.clearTokens();
        handler.next(err);
        return;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final refreshResp = await refreshDio.post<Map<String, dynamic>>(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
      );
      final newAccessToken = refreshResp.data?['access_token']?.toString();
      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _storage.clearTokens();
        handler.next(err);
        return;
      }

      await _storage.saveAccessToken(newAccessToken);

      final retryOptions = err.requestOptions.copyWith(
        headers: <String, dynamic>{
          ...err.requestOptions.headers,
          'Authorization': 'Bearer $newAccessToken',
        },
      );
      final retryDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final retryResp = await retryDio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResp);
      return;
    } catch (_) {
      await _storage.clearTokens();
      handler.next(err);
      return;
    } finally {
      _isRefreshing = false;
    }
  }

  bool _isPublicPath(String path) {
    return path == ApiConstants.login ||
        path == ApiConstants.refresh ||
        path == ApiConstants.forgotPassword ||
        path == ApiConstants.verifyOtp ||
        path == ApiConstants.resetPassword;
  }
}
