import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

bool debugMode = true;

class Logger {
  static late final File file;

  static final List<String> _writeQueue = [];

  static bool _isWriting = false;

  static Future<void> init() async {
    file = await _getLogFile();
  }

  static void log(String message) {
    final callerInfo = _getCallerInfo();
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message (Caller: $callerInfo)';

    if (debugMode) debugPrint(logMessage);

    _writeQueue.add(logMessage);
    if (!_isWriting) {
      _processQueue();
    }

    _sendSingleLogToDiscord(logMessage);
  }

  static void error(String message) {
    final callerInfo = _getCallerInfo();
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[ERROR - $timestamp] $message (Caller: $callerInfo)';

    if (debugMode) debugPrint(logMessage);

    _writeQueue.add(logMessage);
    if (!_isWriting) {
      _processQueue();
    }

    _sendSingleLogToDiscord(logMessage);
  }

  static void _sendSingleLogToDiscord(String message) async {
    try {
      final url = Uri.parse("https://keremkk.glitch.me/discordstorage/dslog");
      final body = jsonEncode({
        "message": jsonEncode({
          "log": message,
        })
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode != 200) {
        error("❗ Log sending failed: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      error("❌ Log sending error: $e");
    }
  }

  static void _processQueue() async {
    _isWriting = true;
    while (_writeQueue.isNotEmpty) {
      final msg = _writeQueue.removeAt(0);
      try {
        await file.writeAsString('$msg\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('Log yazma hatası: $e');
      }
    }
    _isWriting = false;
  }

  static Future<void> clearLogs() async {
    if (await file.exists()) {
      await file.writeAsString('');
    }
  }

  static Future<List<String>> readLogs() async {
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final lines = content.split('\n').where((line) => line.isNotEmpty).toList();

    /*
    // Debug için tüm satırları yazdır
    for (var i = 0; i < lines.length; i++) {
      debugPrint('Satır $i: ${lines[i]}');
    }
     */

    return lines;
  }

  static Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_logs.txt');
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
