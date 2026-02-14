import 'dart:io';

import 'package:flutter/foundation.dart';

class AppLogger {
  static final List<String> logs = <String>[];

  static bool get _isTestMode {
    return Platform.environment.containsKey('FLUTTER_TEST') ||
        const bool.fromEnvironment('FLUTTER_TEST');
  }

  static void clear() => logs.clear();

  static void log(String tag, String message) {
    final line = '[$tag] $message';
    logs.add(line);
    if (!_isTestMode) {
      debugPrint(line);
    }
  }

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer()..write('[$tag][ERROR] $message');
    if (error != null) {
      buffer.write(' | error=$error');
    }
    final line = buffer.toString();
    logs.add(line);
    if (!_isTestMode) {
      debugPrint(line);
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
