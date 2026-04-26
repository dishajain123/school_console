import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../data/models/auth/admin_user.dart';
import '../../data/repositories/auth_repository.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(ref.watch(secureStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(dioClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

class AuthController extends StateNotifier<AsyncValue<AdminUser?>> {
  AuthController(this._repo) : super(const AsyncData(null));

  final AuthRepository _repo;

  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final token = await _repo.login(
        email: email,
        phone: phone,
        password: password,
      );
      // Use the freshly issued access token directly to avoid any storage read race.
      final user = await _repo.me(accessToken: token.accessToken);
      state = AsyncData(user);
    } on DioException catch (e, st) {
      final payload = e.response?.data;
      final status = e.response?.statusCode;
      String message = status == 401
          ? 'Invalid credentials or account is not active yet.'
          : 'Login failed';
      if (payload is Map && payload['detail'] != null) {
        message = payload['detail'].toString();
      } else if (payload is String && payload.trim().isNotEmpty) {
        message = payload;
      }
      state = AsyncError(Exception(message), st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> loadMe() async {
    state = await AsyncValue.guard(_repo.me);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AdminUser?>>(
      (ref) => AuthController(ref.watch(authRepositoryProvider)),
    );
