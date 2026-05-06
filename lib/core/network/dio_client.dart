import 'package:dio/dio.dart';

import '../auth/auth_logout_bus.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/rate_limit_retry_interceptor.dart';

bool _shouldAttachSchoolIdQuery(String path) {
  if (path == ApiConstants.login ||
      path == ApiConstants.refresh ||
      path == ApiConstants.forgotPassword ||
      path == ApiConstants.verifyOtp ||
      path == ApiConstants.resetPassword) {
    return false;
  }
  return true;
}

class DioClient {
  DioClient(this._storage, this._logoutBus)
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final validatedQuery =
              _deepCopyWithSchoolIdValidation(
                    Map<String, dynamic>.from(options.queryParameters),
                  )
                  as Map<String, dynamic>;
          options.queryParameters = validatedQuery;
          final data = options.data;
          if (data is Map<String, dynamic>) {
            options.data = _deepCopyWithSchoolIdValidation(data);
          } else if (data is Map) {
            options.data = _deepCopyWithSchoolIdValidation(
              Map<String, dynamic>.from(data),
            );
          }
          final hasSchoolId =
              options.queryParameters.containsKey('school_id') &&
              options.queryParameters['school_id'] != null;
          // SECURITY NOTE:
          // school_id is added by client for convenience only.
          // Backend MUST derive tenant from JWT and ignore or reject mismatched school_id.
          // Do NOT rely on this value for authorization.
          //
          // WARNING:
          // school_id is sent by the client for convenience only.
          // Backend MUST validate tenant using JWT and ignore mismatches.
          //
          // Never overwrite an existing query `school_id` — callers own explicit values.
          // Auto-append only when absent and the route is not auth-only.
          if (!hasSchoolId && _shouldAttachSchoolIdQuery(options.path)) {
            final schoolId = await _storage.readSchoolId();
            if (schoolId != null &&
                schoolId.trim().isNotEmpty &&
                _uuidRegex.hasMatch(schoolId.trim())) {
              options.queryParameters['school_id'] = schoolId.trim();
            }
          }
          handler.next(options);
        },
      ),
    );
    dio.interceptors.add(ErrorInterceptor());
    dio.interceptors.add(RateLimitRetryInterceptor(dio));
    dio.interceptors.add(AuthInterceptor(_storage, _logoutBus));
  }

  final SecureStorage _storage;
  final AuthLogoutBus _logoutBus;
  final Dio dio;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  /// Validates only **`school_id`** (UUID vs empty string / null).
  ///
  /// Everything else passes through unchanged—no stripping of `_id`
  /// params or coercion of payloads.
  static dynamic _deepCopyWithSchoolIdValidation(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = '${entry.key}';
        final child = _deepCopyWithSchoolIdValidation(entry.value);
        if (key == 'school_id') {
          assertValidSchoolId(child);
        }
        result[key] = child;
      }
      return result;
    }
    if (value is List) {
      return value.map(_deepCopyWithSchoolIdValidation).toList();
    }
    return value;
  }

  /// Non-empty [`String`] values must match [_uuidRegex].
  ///
  /// `null`, `''`, or whitespace-only strings are treated as omitted.
  static void assertValidSchoolId(dynamic schoolIdValue) {
    if (schoolIdValue == null) return;
    if (schoolIdValue is String) {
      final t = schoolIdValue.trim();
      if (t.isEmpty) return;
      if (!_uuidRegex.hasMatch(t)) {
        throw FormatException(
          'Invalid school_id: expected UUID format (RFC), got malformed value.',
          t,
        );
      }
      return;
    }
    throw FormatException(
      'Invalid school_id: expected String, null, or empty string '
      '(got ${schoolIdValue.runtimeType}).',
      schoolIdValue,
    );
  }
}
