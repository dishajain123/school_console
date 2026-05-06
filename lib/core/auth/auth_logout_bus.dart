import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Broadcast channel for **forced** session loss (e.g. refresh failure) from
/// networking code that cannot reach [AuthController] directly.
///
/// [AuthController] subscribes and clears user state so [GoRouter] sends the
/// user back to login without a manual action.
class AuthLogoutBus {
  AuthLogoutBus() : _controller = StreamController<void>.broadcast();

  final StreamController<void> _controller;

  Stream<void> get stream => _controller.stream;

  void notifyLogout() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    _controller.close();
  }
}

final authLogoutBusProvider = Provider<AuthLogoutBus>((ref) {
  final bus = AuthLogoutBus();
  ref.onDispose(bus.dispose);
  return bus;
});
