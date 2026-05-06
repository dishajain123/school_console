import 'package:dio/dio.dart';
import 'dart:async';

import '../../logging/crash_reporter.dart';
import '../../auth/auth_logout_bus.dart';
import '../../constants/api_constants.dart';
import '../../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._logoutBus);

  final SecureStorage _storage;
  final AuthLogoutBus _logoutBus;
  Completer<String>? _refreshCompleter;

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
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final requestPath = err.requestOptions.path;
    if (_isPublicPath(requestPath) || requestPath == ApiConstants.refresh) {
      handler.next(err);
      return;
    }

    if (_refreshCompleter != null) {
      try {
        final token = await _refreshCompleter!.future;
        final retryResp = await _retryWithToken(err.requestOptions, token);
        handler.resolve(retryResp);
      } catch (e, stack) {
        CrashReporter.log(e, stack);
        handler.next(err);
      }
      return;
    }

    _refreshCompleter = Completer<String>();
    try {
      final newAccessToken = await _doRefresh();
      _refreshCompleter!.complete(newAccessToken);
      await _storage.saveAccessToken(newAccessToken);
      final retryResp = await _retryWithToken(err.requestOptions, newAccessToken);
      handler.resolve(retryResp);
      return;
    } catch (e, stack) {
      _refreshCompleter?.completeError(e);
      CrashReporter.log(e, stack);
      await _storage.clearTokens();
      _logoutBus.notifyLogout();
      handler.next(err);
      return;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<String> _doRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw StateError('Missing refresh token');
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
      throw StateError('Refresh response missing access_token');
    }
    return newAccessToken;
  }

  Future<Response<dynamic>> _retryWithToken(
    RequestOptions requestOptions,
    String token,
  ) async {
    final retryOptions = requestOptions.copyWith(
      headers: <String, dynamic>{
        ...requestOptions.headers,
        'Authorization': 'Bearer $token',
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
    return retryDio.fetch<dynamic>(retryOptions);
  }

  bool _isPublicPath(String path) {
    return path == ApiConstants.login ||
        path == ApiConstants.refresh ||
        path == ApiConstants.forgotPassword ||
        path == ApiConstants.verifyOtp ||
        path == ApiConstants.resetPassword;
  }
}
