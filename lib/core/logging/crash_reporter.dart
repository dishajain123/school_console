import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Central error logging — replace or extend with Sentry/Crashlytics in production.
abstract final class CrashReporter {
  static void log(Object error, [StackTrace? stackTrace]) {
    developer.log(
      '$error',
      name: 'CrashReporter',
      error: error,
      stackTrace: stackTrace,
    );
    if (kDebugMode && stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
