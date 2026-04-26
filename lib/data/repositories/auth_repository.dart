import 'package:dio/dio.dart';

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
      '/auth/login',
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
      '/auth/me',
      options: accessToken == null || accessToken.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return AdminUser.fromJson(resp.data ?? {});
  }

  Future<void> logout() async {
    final refresh = await _storage.readRefreshToken();
    try {
      await _client.dio.post('/auth/logout', data: {'refresh_token': refresh});
    } on DioException {
      // Best effort logout; always clear local session.
    }
    await _storage.clearTokens();
  }
}
