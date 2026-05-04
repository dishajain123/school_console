import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage.dart';
import '../models/auth/admin_user.dart';
import '../models/auth/token_response.dart';

class AuthRepository {
  AuthRepository(this._client, this._storage);

  final DioClient _client;
  final SecureStorage _storage;

  Future<TokenResponse> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
      },
    );
    final token = TokenResponse.fromJson(resp.data ?? {});
    await _storage.saveTokens(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
    );
    return token;
  }

  Future<AdminUser> me({String? accessToken}) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.me,
      options: accessToken == null || accessToken.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final user = AdminUser.fromJson(resp.data ?? {});
    if (user.schoolId != null && user.schoolId!.trim().isNotEmpty) {
      await _storage.saveSchoolId(user.schoolId!.trim());
    }
    return user;
  }

  Future<String?> resolveSchoolContext({String? accessToken}) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.schools,
      queryParameters: {'page': 1, 'page_size': 1, 'is_active': true},
      options: accessToken == null || accessToken.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final items = (resp.data?['items'] as List?) ?? const <dynamic>[];
    if (items.isEmpty) return null;
    final first = items.first;
    if (first is Map && first['id'] != null) {
      final id = first['id'].toString().trim();
      if (id.isNotEmpty) {
        await _storage.saveSchoolId(id);
        return id;
      }
    }
    return null;
  }

  Future<void> logout() async {
    final refresh = await _storage.readRefreshToken();
    try {
      await _client.dio
          .post(ApiConstants.logout, data: {'refresh_token': refresh});
    } on DioException {
      // Best effort logout; always clear local session.
    }
    await _storage.clearTokens();
  }
}
