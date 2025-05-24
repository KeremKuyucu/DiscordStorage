import 'dart:io';
import 'package:flutter/foundation.dart';

bool debugMode = false;
class Logger {
  static void log(String message) {
    final callerInfo = _getCallerInfo();
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message (Caller: $callerInfo)';

    if(debugMode) {
      debugPrint(logMessage);
    }
  }

  static void error(String message) {
    final callerInfo = _getCallerInfo();
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[ERROR - $timestamp] $message (Caller: $callerInfo)';

    debugPrint(logMessage);
  }

  static String _getCallerInfo() {
    try {
      final stackTrace = StackTrace.current;
      final lines = stackTrace.toString().split('\n');
      if (lines.length > 2) {
        final callerLine = lines[2].trim();
        final regExp = RegExp(r'\((.*?):(\d+):(\d+)\)');
        final match = regExp.firstMatch(callerLine);

        if (match != null) {
          final filePath = match.group(1);
          final line = match.group(2);
          final column = match.group(3);
          final fileName = filePath?.split(Platform.pathSeparator).last ?? 'unknown';
          return '$fileName:$line:$column';
        } else {
          return callerLine;
        }
      }
      return 'caller info not found';
    } catch (e) {
      return 'error getting caller info: $e';
    }
  }
}
