import 'package:local_notifier/local_notifier.dart';
import 'package:discord_storage/services/logger_service.dart';
import 'package:discord_storage/services/localization_service.dart';

enum NotificationPriority { low, normal, high, urgent }
enum NotificationType { info, success, warning, error, progress }

class NotificationService {
  static final NotificationService instance = NotificationService._privateConstructor();

  // Windows ilerleme bildirimi için throttling (bildirim kirliliğini ve ses spam'ini engeller)
  DateTime? _lastProgressUpdateTime;
  int? _lastProgressPercent;

  NotificationService._privateConstructor();

  static Future<void> init() async {
    await instance.initializeNotifications();
  }

  Future<void> initializeNotifications() async {
    try {
      Logger.info('Initializing local_notifier on Windows...');
      await localNotifier.setup(
        appName: 'DiscordStorage',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      Logger.info('local_notifier initialized successfully.');
    } catch (e) {
      Logger.error('Error initializing notifications: $e');
    }
  }

  /// Temel bildirim gösterme
  Future<void> showNotification(
    String title,
    String body, {
    int? id,
    NotificationPriority priority = NotificationPriority.normal,
    NotificationType type = NotificationType.info,
    bool playSound = false,
    String? payload,
    Duration? timeout,
  }) async {
    try {
      Logger.info('Showing notification: $title - $body (playSound: $playSound)');

      final notification = LocalNotification(
        title: title,
        body: body,
        silent: !playSound, // playSound false ise bildirim tamamen sessizdir
      );

      await notification.show();
    } catch (e) {
      Logger.error('Error showing notification: $e');
    }
  }

  /// İlerleme bildirimi (Yükleme/İndirme sırasında çağrılır)
  /// Windows'ta SES ÇIKMAZ ve bildirim kirliliğini önlemek için rate-limit uygulanır.
  Future<void> showProgressNotification({
    required int current,
    required int total,
    int? id,
    String? title,
    String? operation,
    String? fileName,
    bool showDetailedProgress = true,
    int barWidth = 25,
    bool showSpeed = false,
    double? speed, // MB/s
    Duration? estimatedTime,
  }) async {
    if (total <= 0 || current < 0) {
      return;
    }

    try {
      final progress = (current / total).clamp(0.0, 1.0);
      final progressPercent = (progress * 100).round();
      final isComplete = current >= total;
      final now = DateTime.now();

      // Throttling: Her parçada bildirim spam'i yapma
      if (!isComplete && _lastProgressUpdateTime != null) {
        final timePassed = now.difference(_lastProgressUpdateTime!).inMilliseconds;
        final percentDelta = (progressPercent - (_lastProgressPercent ?? 0)).abs();
        if (timePassed < 3000 && percentDelta < 15) {
          return;
        }
      }

      _lastProgressUpdateTime = now;
      _lastProgressPercent = progressPercent;

      // Başlık oluştur
      String notificationTitle = title ?? Language.get('operationInProgress');
      if (fileName != null) {
        notificationTitle = '$notificationTitle: $fileName';
      }

      // İçerik oluştur
      final body = '$progressPercent% (${_formatBytes(current)} / ${_formatBytes(total)})';

      final notification = LocalNotification(
        title: notificationTitle,
        body: body,
        silent: true, // KESİNLİKLE SES ÇIKMAZ
      );

      await notification.show();

      // İşlem tamamlandıysa
      if (isComplete) {
        _lastProgressUpdateTime = null;
        _lastProgressPercent = null;
        await _handleProgressComplete(id ?? 100, operation, fileName);
      }
    } catch (e) {
      Logger.error('Error showing progress notification: $e');
    }
  }

  /// İlerleme tamamlandığında çağrılır (tek seferlik ses çalabilir)
  Future<void> _handleProgressComplete(int id, String? operation, String? fileName) async {
    Logger.info('Operation completed (ID: $id)');

    String title = Language.get('operationCompletedTitle');
    String body = Language.get('operationCompletedBody');

    if (operation != null) {
      title = '$operation Tamamlandı';
    }

    if (fileName != null) {
      body = '$fileName başarıyla işlendi';
    }

    await showSuccessNotification(title, body, playSound: true);
  }

  /// Başarı bildirimi
  Future<void> showSuccessNotification(
    String title,
    String message, {
    bool playSound = true,
    String? payload,
    Duration? timeout,
  }) async {
    await showNotification(
      title,
      message,
      type: NotificationType.success,
      priority: NotificationPriority.high,
      playSound: playSound,
      payload: payload,
      timeout: timeout,
    );
  }

  /// Hata bildirimi
  Future<void> showErrorNotification(
    String title,
    String error, {
    String? details,
    bool expandable = true,
    String? payload,
  }) async {
    String body = error;
    if (details != null && details.isNotEmpty) {
      body += '\n\nDetaylar: $details';
    }

    await showNotification(
      title,
      body,
      type: NotificationType.error,
      priority: NotificationPriority.urgent,
      playSound: true,
      payload: payload,
    );
  }

  /// Uyarı bildirimi
  Future<void> showWarningNotification(
    String title,
    String message, {
    String? payload,
  }) async {
    await showNotification(
      title,
      message,
      type: NotificationType.warning,
      priority: NotificationPriority.high,
      playSound: false,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {}
  Future<void> cancelAllNotifications() async {}
  Future<void> cancelProgressNotification([int? id]) async {}

  int get activeNotificationCount => 0;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
