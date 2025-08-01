import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

bool debugMode = kDebugMode;

enum LogLevel {
  info('INFO'),
  warning('WARNING'),
  error('ERROR'),
  debug('DEBUG');

  const LogLevel(this.name);
  final String name;
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String callerInfo;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.callerInfo,
  });

  String toFormattedString() {
    final timestampStr = timestamp.toIso8601String();
    return '[${level.name} - $timestampStr] $message (Caller: $callerInfo)';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    'callerInfo': callerInfo,
  };

  // Create LogEntry from old format string
  static LogEntry? fromLegacyString(String logString) {
    try {
      // Parse: [LEVEL - TIMESTAMP] MESSAGE (Caller: CALLER_INFO)
      final regExp = RegExp(r'\[(\w+) - (.*?)\] (.*?) \(Caller: (.*?)\)$');
      final match = regExp.firstMatch(logString);

      if (match != null) {
        final levelStr = match.group(1)!;
        final timestampStr = match.group(2)!;
        final message = match.group(3)!;
        final callerInfo = match.group(4)!;

        LogLevel level;
        if (levelStr == 'ERROR') {
          level = LogLevel.error;
        } else if (levelStr == 'WARNING') {
          level = LogLevel.warning;
        } else if (levelStr == 'DEBUG') {
          level = LogLevel.debug;
        } else {
          level = LogLevel.info;
        }

        return LogEntry(
          timestamp: DateTime.parse(timestampStr),
          level: level,
          message: message,
          callerInfo: callerInfo,
        );
      }

      // Try old format: [TIMESTAMP] MESSAGE (Caller: CALLER_INFO)
      final oldRegExp = RegExp(r'\[(.*?)\] (.*?) \(Caller: (.*?)\)$');
      final oldMatch = oldRegExp.firstMatch(logString);

      if (oldMatch != null) {
        final timestampStr = oldMatch.group(1)!;
        final message = oldMatch.group(2)!;
        final callerInfo = oldMatch.group(3)!;

        return LogEntry(
          timestamp: DateTime.parse(timestampStr),
          level: LogLevel.info,
          message: message,
          callerInfo: callerInfo,
        );
      }
    } catch (e) {
      debugPrint('Log satırı parse hatası: $e');
    }
    return null;
  }
}

class Logger {
  static late final File _file;
  static final List<String> _writeQueue = []; // Keep as String for backward compatibility
  static bool _isWriting = false;
  static bool _isInitialized = false;
  static final Completer<void> _initCompleter = Completer<void>();

  // Log rotation settings
  static const int maxLogSize = 5 * 1024 * 1024; // 5MB
  static const int maxLogFiles = 3;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      _file = await _getLogFile();
      _isInitialized = true;
      _initCompleter.complete();

      // Check if log rotation is needed
      await _checkLogRotation();
    } catch (e) {
      _initCompleter.completeError(e);
      rethrow;
    }
  }

  static Future<void> _ensureInitialized() async {
    print('_ensureInitialized called, _isInitialized: $_isInitialized');

    if (_isInitialized) {
      print('Already initialized');
      return;
    }

    if (!_initCompleter.isCompleted) {
      print('Waiting for initialization to complete...');
      try {
        await _initCompleter.future.timeout(Duration(seconds: 10));
        print('Initialization completed');
      } catch (e) {
        print('Initialization timeout or error: $e');
        // Try to initialize again
        await _forceInit();
      }
    } else {
      print('Init completer completed but not initialized, forcing init...');
      await _forceInit();
    }
  }

  static Future<void> _forceInit() async {
    try {
      print('Force initializing...');
      _file = await _getLogFile();
      _isInitialized = true;
      print('Force init completed');
    } catch (e) {
      print('Force init failed: $e');
      rethrow;
    }
  }

  // Backward compatible methods
  static void log(String message) {
    _logWithLevel(message, LogLevel.info);
  }

  static void error(String message) {
    _logWithLevel(message, LogLevel.error);
  }

  static void info(String message) {
    _logWithLevel(message, LogLevel.info);
  }

  static void warning(String message) {
    _logWithLevel(message, LogLevel.warning);
  }

  static void debug(String message) {
    _logWithLevel(message, LogLevel.debug);
  }

  static void _logWithLevel(String message, LogLevel level) {
    final callerInfo = _getCallerInfo();
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[${level.name} - $timestamp] $message (Caller: $callerInfo)';

    if (debugMode || level != LogLevel.debug) {
      debugPrint(logMessage);
    }

    _writeQueue.add(logMessage);
    if (!_isWriting) {
      _processQueue();
    }
  }

  static Future<void> _processQueue() async {
    if (_isWriting) return;

    _isWriting = true;

    try {
      await _ensureInitialized();

      while (_writeQueue.isNotEmpty) {
        final message = _writeQueue.removeAt(0);
        try {
          await _file.writeAsString('$message\n', mode: FileMode.append);
        } catch (e) {
          debugPrint('Log yazma hatası: $e');
          // Re-add to queue for retry (with limit to prevent infinite loop)
          if (_writeQueue.length < 1000) {
            _writeQueue.insert(0, message);
          }
          break;
        }
      }
    } finally {
      _isWriting = false;
    }
  }

  static Future<void> clearLogs() async {
    await _ensureInitialized();

    if (await _file.exists()) {
      await _file.writeAsString('');
    }
  }

  // Enhanced method that returns LogEntry objects
  static Future<List<LogEntry>> readLogs({
    LogLevel? filterLevel,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    print('readLogs called with filterLevel: $filterLevel, limit: $limit');

    try {
      await _ensureInitialized();
      print('Logger initialized successfully');

      if (!await _file.exists()) {
        print('Log file does not exist');
        return [];
      }

      print('Reading log file...');
      final content = await _file.readAsString();
      print('File content length: ${content.length}');

      final lines = content.split('\n').where((line) => line.isNotEmpty);
      print('Found ${lines.length} non-empty lines');

      List<LogEntry> logs = [];

      for (final line in lines) {
        final entry = LogEntry.fromLegacyString(line);
        if (entry != null) {
          // Apply filters
          if (filterLevel != null && entry.level != filterLevel) continue;
          if (fromDate != null && entry.timestamp.isBefore(fromDate)) continue;
          if (toDate != null && entry.timestamp.isAfter(toDate)) continue;

          logs.add(entry);
        }
      }

      print('Parsed ${logs.length} valid log entries');

      // Sort by timestamp (newest first)
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Apply limit
      if (limit != null && logs.length > limit) {
        logs = logs.take(limit).toList();
      }

      print('Returning ${logs.length} logs after filtering and limiting');
      return logs;
    } catch (e) {
      print('Error in readLogs: $e');
      debugPrint('Log okuma hatası: $e');
      return [];
    }
  }

  // Legacy method for backward compatibility
  static Future<List<String>> readLogsAsStrings() async {
    await _ensureInitialized();

    if (!await _file.exists()) return [];

    final content = await _file.readAsString();
    final lines = content.split('\n').where((line) => line.isNotEmpty).toList();
    return lines;
  }

  static Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/discordstorage_logs.txt');
  }

  static Future<void> _checkLogRotation() async {
    if (!await _file.exists()) return;

    final stat = await _file.stat();
    if (stat.size > maxLogSize) {
      await _rotateLogFiles();
    }
  }

  static Future<void> _rotateLogFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final baseName = 'discordstorage_logs';

    // Move existing backup files
    for (int i = maxLogFiles - 1; i > 0; i--) {
      final oldFile = File('${dir.path}/${baseName}_$i.txt');
      final newFile = File('${dir.path}/${baseName}_${i + 1}.txt');

      if (await oldFile.exists()) {
        if (i == maxLogFiles - 1) {
          await oldFile.delete(); // Delete oldest
        } else {
          await oldFile.rename(newFile.path);
        }
      }
    }

    // Move current log to backup
    final backupFile = File('${dir.path}/${baseName}_1.txt');
    if (await _file.exists()) {
      await _file.rename(backupFile.path);
    }

    // Create new log file
    _file = File('${dir.path}/$baseName.txt');
  }

  static String _getCallerInfo() {
    try {
      final stackTrace = StackTrace.current;
      final lines = stackTrace.toString().split('\n');

      // Skip deeper into the stack to get the real external caller (2-levels up)
      if (lines.length > 4) {
        final callerLine = lines[4].trim(); // ← buradaki index ile derinliği ayarlarsın
        final regExp = RegExp(r'\((.*?):(\d+):(\d+)\)');
        final match = regExp.firstMatch(callerLine);
        if (match != null) {
          final filePath = match.group(1);
          final lineNum = match.group(2);
          final column = match.group(3);
          final fileName = filePath?.split(Platform.pathSeparator).last ?? 'unknown';
          return '$fileName:$lineNum:$column';
        } else {
          return callerLine;
        }
      }
      return 'caller info not found';
    } catch (e) {
      return 'error getting caller info: $e';
    }
  }


  // Utility methods
  static Future<int> getLogFileSize() async {
    await _ensureInitialized();
    if (await _file.exists()) {
      final stat = await _file.stat();
      return stat.size;
    }
    return 0;
  }

  static Future<void> exportLogs(String exportPath) async {
    await _ensureInitialized();
    if (await _file.exists()) {
      await _file.copy(exportPath);
    }
  }
}