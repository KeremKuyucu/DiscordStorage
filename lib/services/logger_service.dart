import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
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

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'callerInfo': callerInfo,
    };
  }

  // Create from JSON
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere((e) => e.name == json['level']),
      message: json['message'],
      callerInfo: json['callerInfo'],
    );
  }

  // Create from legacy string format (for backward compatibility)
  static LogEntry? fromLegacyString(String logString) {
    try {
      // Parse log format: "[TIMESTAMP] [LEVEL] MESSAGE (CALLER)"
      final regex = RegExp(r'\[(.*?)\] \[(.*?)\] (.*?) \((.*?)\)');
      final match = regex.firstMatch(logString);

      if (match != null) {
        final timestampStr = match.group(1)!;
        final levelStr = match.group(2)!;
        final message = match.group(3)!;
        final callerInfo = match.group(4)!;

        final timestamp = DateTime.tryParse(timestampStr) ?? DateTime.now();
        final level = LogLevel.values.firstWhere(
              (e) => e.name.toUpperCase() == levelStr.toUpperCase(),
          orElse: () => LogLevel.info,
        );

        return LogEntry(
          timestamp: timestamp,
          level: level,
          message: message,
          callerInfo: callerInfo,
        );
      }
    } catch (e) {
      debugPrint('Error parsing legacy log string: $e');
    }
    return null;
  }

  // Convert to formatted string for display/export
  String toFormattedString() {
    return '[${timestamp.toLocal()}] [${level.name.toUpperCase()}] $message ($callerInfo)';
  }
}

class Logger {
  static Logger? _instance;
  static Logger get instance => _instance ??= Logger._internal();

  Logger._internal();

  static const String _logFileName = 'app_logs.jsonl';
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  File? _logFile;
  bool _isInitialized = false;

  // Initialize the logger
  static Future<void> init() async {
    await instance._init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    try {
      Directory logDir;
      if (Platform.isWindows) {
        // Inno Setup'ın uygulamayı kurduğu yer: %APPDATA%\DiscordStorage\logs
        final appData = Platform.environment['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          logDir = Directory('$appData\\DiscordStorage\\logs');
        } else {
          final exeDir = File(Platform.resolvedExecutable).parent;
          logDir = Directory('${exeDir.path}\\logs');
        }
      } else {
        logDir = await getApplicationSupportDirectory();
      }

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      _logFile = File(p.join(logDir.path, _logFileName));

      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }

      // Belgeler (Documents) klasöründeki eski log dosyasını temizle
      try {
        if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            final oldDocLog = File('$userProfile\\Documents\\$_logFileName');
            if (await oldDocLog.exists()) {
              await oldDocLog.delete();
            }
          }
        }
      } catch (_) {}

      // Check file size and rotate if necessary
      await _rotateLogIfNeeded();

      _isInitialized = true;

      // Log initialization
      await _writeLog(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'Logger initialized',
        callerInfo: 'Logger._init',
      ));
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  // Rotate log file if it's too large
  Future<void> _rotateLogIfNeeded() async {
    if (_logFile == null) return;

    try {
      final stat = await _logFile!.stat();
      if (stat.size > _maxFileSizeBytes) {
        // Create backup and clear current file
        final backupFile = File('${_logFile!.path}.backup');
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
        await _logFile!.copy(backupFile.path);
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      debugPrint('Error rotating log file: $e');
    }
  }

  // Get caller information
  static String _getCallerInfo() {
    final stackTrace = StackTrace.current;
    final frames = stackTrace.toString().split('\n');

    // Skip frames until we find the first frame outside this logger
    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      if (!frame.contains('Logger') && !frame.contains('dart:core')) {
        // Extract file and line information
        final match = RegExp(r'#\d+\s+(.+?)\s+\((.+?):(\d+):\d+\)').firstMatch(frame);
        if (match != null) {
          final function = match.group(1) ?? 'unknown';
          final file = match.group(2)?.split('/').last ?? 'unknown';
          final line = match.group(3) ?? '0';
          return '$file:$line ($function)';
        }
        break;
      }
    }
    return 'unknown';
  }

  // Async queue to ensure sequential and atomic log writes without file collision
  Future<void> _writeQueue = Future.value();

  // Write log entry to file
  Future<void> _writeLog(LogEntry entry) {
    return _writeQueue = _writeQueue.then((_) async {
      if (_logFile == null) return;

      try {
        final jsonLine = '${jsonEncode(entry.toJson())}\n';
        await _logFile!.writeAsString(jsonLine, mode: FileMode.append, flush: true);
      } catch (e) {
        debugPrint('Error writing log: $e');
      }
    });
  }

  // Public logging methods
  static Future<void> debug(String message) async {
    await instance._log(LogLevel.debug, message);
  }

  static Future<void> info(String message) async {
    await instance._log(LogLevel.info, message);
  }

  static Future<void> warning(String message) async {
    await instance._log(LogLevel.warning, message);
  }

  static Future<void> error(String message, [dynamic error, StackTrace? stackTrace]) async {
    String fullMessage = message;
    if (error != null) {
      fullMessage += ' | Error: $error';
    }
    if (stackTrace != null) {
      fullMessage += ' | StackTrace: $stackTrace';
    }
    await instance._log(LogLevel.error, fullMessage);
  }

  Future<void> _log(LogLevel level, String message) async {
    if (!_isInitialized) {
      await _init();
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      callerInfo: _getCallerInfo(),
    );

    // Write to file
    await _writeLog(entry);

    // Also print to console in debug mode
    if (kDebugMode) {
      final color = _getConsoleColor(level);
      final resetColor = '\x1B[0m';
      final callerInfo = entry.callerInfo.split('(').first;
      print('$color[${entry.timestamp}] [${level.name.toUpperCase()}] $message [$callerInfo]$resetColor');
    }
  }

  String _getConsoleColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '\x1B[36m'; // Cyan
      case LogLevel.info:
        return '\x1B[32m'; // Green
      case LogLevel.warning:
        return '\x1B[33m'; // Yellow
      case LogLevel.error:
        return '\x1B[31m'; // Red
    }
  }

  // Read logs with filtering
  static Future<List<LogEntry>> readLogs({
    LogLevel? filterLevel,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 1000,
  }) async {
    return await instance._readLogs(
      filterLevel: filterLevel,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
    );
  }

  Future<List<LogEntry>> _readLogs({
    LogLevel? filterLevel,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 1000,
  }) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return [];
    }

    try {
      final content = await _logFile!.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

      List<LogEntry> entries = [];

      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
          continue; // Kırpılmış veya bozuk satır parçalarını atla
        }

        try {
          final json = jsonDecode(trimmed);
          if (json is Map<String, dynamic>) {
            final entry = LogEntry.fromJson(json);

            // Apply filters
            if (filterLevel != null && entry.level != filterLevel) continue;
            if (fromDate != null && entry.timestamp.isBefore(fromDate)) continue;
            if (toDate != null && entry.timestamp.isAfter(toDate)) continue;

            entries.add(entry);
          }
        } catch (_) {
          // Format bozukluklarında konsola hata basmadan devam et
        }
      }

      // Sort by timestamp (newest first)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Apply limit
      if (entries.length > limit) {
        entries = entries.take(limit).toList();
      }

      return entries;
    } catch (e) {
      debugPrint('Error reading logs: $e');
      return [];
    }
  }

  // Read logs as strings (legacy method for backward compatibility)
  static Future<List<String>> readLogsAsStrings() async {
    final entries = await readLogs();
    return entries.map((e) => e.toFormattedString()).toList();
  }

  // Clear all logs
  static Future<void> clearLogs() async {
    await instance._clearLogs();
  }

  Future<void> _clearLogs() async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString('');
      await info('Logs cleared');
    } catch (e) {
      debugPrint('Error clearing logs: $e');
    }
  }

  // Get log file size
  static Future<int> getLogFileSize() async {
    if (instance._logFile == null || !await instance._logFile!.exists()) {
      return 0;
    }

    try {
      final stat = await instance._logFile!.stat();
      return stat.size;
    } catch (e) {
      return 0;
    }
  }

  // Get log file path
  static Future<String?> getLogFilePath() async {
    if (instance._logFile == null) {
      await instance._init();
    }
    return instance._logFile?.path;
  }

  // Get log statistics
  static Future<Map<LogLevel, int>> getLogStatistics() async {
    final entries = await readLogs(limit: 10000);
    final stats = <LogLevel, int>{};

    for (final level in LogLevel.values) {
      stats[level] = entries.where((e) => e.level == level).length;
    }

    return stats;
  }
}