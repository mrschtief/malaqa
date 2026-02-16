import 'dart:io';

import 'package:flutter/foundation.dart';

enum AppLogLevel {
  debug,
  info,
  warn,
  error,
}

class AppLogger {
  static final List<String> logs = <String>[];

  /// Change this to control verbosity globally.
  /// - debug: extremely chatty (frame-level)
  /// - info: normal runtime logging
  /// - warn/error: only problems
  static AppLogLevel level = kDebugMode ? AppLogLevel.debug : AppLogLevel.info;

  static final Map<String, DateTime> _throttle = <String, DateTime>{};

  static bool get _isTestMode {
    return Platform.environment.containsKey('FLUTTER_TEST') ||
        const bool.fromEnvironment('FLUTTER_TEST');
  }

  static void clear() => logs.clear();

  static void debug(String tag, String message) {
    _log(AppLogLevel.debug, tag, message);
  }

  static void info(String tag, String message) {
    _log(AppLogLevel.info, tag, message);
  }

  static void warn(String tag, String message) {
    _log(AppLogLevel.warn, tag, message);
  }

  static void log(String tag, String message) {
    // Backwards compatible (kept for existing calls).
    info(tag, message);
  }

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer()..write(message);
    if (error != null) {
      buffer.write(' | error=$error');
    }
    _log(AppLogLevel.error, tag, buffer.toString(), stackTrace: stackTrace);
  }

  /// Emit at most once per [every].
  static void throttled(
    String key,
    Duration every,
    void Function() fn,
  ) {
    final now = DateTime.now();
    final last = _throttle[key];
    if (last != null && now.difference(last) < every) {
      return;
    }
    _throttle[key] = now;
    fn();
  }

  static void _log(
    AppLogLevel msgLevel,
    String tag,
    String message, {
    StackTrace? stackTrace,
  }) {
    if (msgLevel.index < level.index) {
      return;
    }

    final levelName = msgLevel.name.toUpperCase();
    final line = '[$tag][$levelName] $message';
    logs.add(line);

    if (_isTestMode) {
      return;
    }

    debugPrint(line);
    if (stackTrace != null && msgLevel.index >= AppLogLevel.error.index) {
      debugPrint(stackTrace.toString());
    }
  }
}
