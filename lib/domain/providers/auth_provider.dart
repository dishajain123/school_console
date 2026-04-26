import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    state = await AsyncValue.guard(() async {
      await _repo.login(email: email, phone: phone, password: password);
      return _repo.me();
    });
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
