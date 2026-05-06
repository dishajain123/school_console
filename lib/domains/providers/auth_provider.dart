import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../../core/auth/auth_logout_bus.dart';
import '../../core/constants/api_constants.dart';
import '../../core/logging/crash_reporter.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../data/models/auth/admin_user.dart';
import '../../data/repositories/auth_repository.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(
    ref.watch(secureStorageProvider),
    ref.watch(authLogoutBusProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(dioClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

class AuthController extends StateNotifier<AsyncValue<AdminUser?>> {
  AuthController(
    this._repo,
    this._storage,
    AuthLogoutBus logoutBus,
  ) : super(const AsyncLoading()) {
    _logoutSubscription = logoutBus.stream.listen((_) {
      state = const AsyncData(null);
    });
  }

  final AuthRepository _repo;
  final SecureStorage _storage;

  StreamSubscription<void>? _logoutSubscription;

  @override
  void dispose() {
    _logoutSubscription?.cancel();
    super.dispose();
  }

  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final token = await _repo
          .login(
            email: email,
            phone: phone,
            password: password,
          )
          .timeout(const Duration(seconds: 12));
      // Use the freshly issued access token directly to avoid any storage read race.
      final user = await _repo
          .me(accessToken: token.accessToken)
          .timeout(const Duration(seconds: 12));
      var resolvedUser = user;
      if ((resolvedUser.schoolId == null || resolvedUser.schoolId!.isEmpty) &&
          resolvedUser.role.toUpperCase() == 'STAFF_ADMIN') {
        try {
          final schoolId =
              await _repo.resolveSchoolContext(accessToken: token.accessToken);
          if (schoolId != null && schoolId.isNotEmpty) {
            resolvedUser = resolvedUser.copyWith(schoolId: schoolId);
          }
        } catch (e, stack) {
          CrashReporter.log(e, stack);
          await _storage.clearTokens();
          throw Exception('Failed to resolve school context');
        }
        if (resolvedUser.schoolId == null ||
            resolvedUser.schoolId!.trim().isEmpty) {
          await _storage.clearTokens();
          throw Exception('Failed to resolve school context');
        }
      }
      if (resolvedUser.role.toUpperCase() != 'STAFF_ADMIN') {
        await _storage.clearTokens();
        state = AsyncError(
          'This web console is only for Staff Admin (school office). Other roles use the mobile app.',
          StackTrace.current,
        );
        return;
      }
      state = AsyncData(resolvedUser);
    } on TimeoutException catch (e, st) {
      CrashReporter.log(e, st);
      state = AsyncError(
        'Login request timed out. Please ensure backend is running and try again.',
        st,
      );
    } on DioException catch (e, st) {
      final message = _messageFromDioError(e);
      state = AsyncError(message, st);
    } catch (e, st) {
      state = AsyncError(_normalizeErrorMessage(e), st);
    }
  }

  String _messageFromDioError(DioException e) {
    // Network / DNS / connection refused
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.response == null) {
      return 'Cannot reach backend. Ensure API is running at ${ApiConstants.baseUrl}.';
    }

    final payload = e.response?.data;
    final status = e.response?.statusCode;

    // Our backend often returns: { message, error: { details } }
    if (payload is Map) {
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final detail = payload['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      final error = payload['error'];
      if (error is Map) {
        final details = error['details'];
        if (details is String && details.trim().isNotEmpty) {
          return details.trim();
        }
      }
    } else if (payload is String && payload.trim().isNotEmpty) {
      return payload.trim();
    }

    if (status == 401) {
      return 'Invalid credentials or account is not active yet.';
    }
    return 'Login failed. Please try again.';
  }

  String _normalizeErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  Future<void> loadMe() async {
    state = await AsyncValue.guard(_repo.me);
  }

  Future<void> restoreSessionIfAny() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.trim().isEmpty) {
      state = const AsyncData(null);
      return;
    }
    try {
      var user = await _repo.me(accessToken: token);
      if ((user.schoolId == null || user.schoolId!.isEmpty) &&
          user.role.toUpperCase() == 'STAFF_ADMIN') {
        try {
          final schoolId = await _repo.resolveSchoolContext(accessToken: token);
          if (schoolId != null && schoolId.isNotEmpty) {
            user = user.copyWith(schoolId: schoolId);
          }
        } catch (e, stack) {
          CrashReporter.log(e, stack);
          throw Exception('Failed to resolve school context');
        }
        if (user.schoolId == null || user.schoolId!.trim().isEmpty) {
          throw Exception('Failed to resolve school context');
        }
      }
      if (user.role.toUpperCase() != 'STAFF_ADMIN') {
        await _storage.clearTokens();
        state = const AsyncData(null);
        return;
      }
      state = AsyncData(user);
    } catch (e, stack) {
      CrashReporter.log(e, stack);
      await _storage.clearTokens();
      state = const AsyncData(null);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AdminUser?>>(
      (ref) => AuthController(
        ref.watch(authRepositoryProvider),
        ref.watch(secureStorageProvider),
        ref.watch(authLogoutBusProvider),
      ),
    );

final authBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(authControllerProvider.notifier).restoreSessionIfAny();
});
