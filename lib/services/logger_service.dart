import 'package:flutter/foundation.dart';

class Logger {
  static final bool isDebug = kDebugMode;

  static void log(String message) {
    if (isDebug) {
      debugPrint(message);
    }
  }
}
