import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

class DioClient {
  DioClient(this._storage)
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
          options.queryParameters = _sanitizeMap(options.queryParameters);
          if (options.data is Map<String, dynamic>) {
            options.data = _sanitizeMap(options.data as Map<String, dynamic>);
          }
          final hasSchoolId =
              options.queryParameters.containsKey('school_id') &&
              options.queryParameters['school_id'] != null;
          if (!hasSchoolId) {
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
    dio.interceptors.add(AuthInterceptor(_storage));
    dio.interceptors.add(ErrorInterceptor());
  }

  final SecureStorage _storage;
  final Dio dio;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> source) {
    final out = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key;
      final value = _sanitizeValue(key, entry.value);
      if (value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  static dynamic _sanitizeValue(String key, dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final v = value.trim();
      if (v.isEmpty) return null;
      if (v.toLowerCase() == 'null' || v.toLowerCase() == 'undefined') {
        return null;
      }
      if ((key.endsWith('_id') || key == 'id') && !_uuidRegex.hasMatch(v)) {
        return null;
      }
      return v;
    }

    if (value is Map<String, dynamic>) {
      final nested = _sanitizeMap(value);
      return nested.isEmpty ? null : nested;
    }

    if (value is List) {
      final list = value
          .map((e) => _sanitizeValue(key, e))
          .where((e) => e != null)
          .toList();
      return list.isEmpty ? null : list;
    }

    return value;
  }
}
