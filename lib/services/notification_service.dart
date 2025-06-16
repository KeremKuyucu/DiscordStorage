import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';

enum NotificationPriority { low, normal, high, urgent }
enum NotificationType { info, success, warning, error, progress }

class NotificationService {
  static final NotificationService instance = NotificationService._privateConstructor();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Bildirim kanalları
  static const String _fileChannelId = 'discordstorage_file';
  static const String _progressChannelId = 'discordstorage_progress';
  static const String _errorChannelId = 'discordstorage_error';
  static const String _successChannelId = 'discordstorage_success';

  // Özel ID'ler
  static const int _progressNotificationId = 100;
  static const int _errorNotificationId = 200;
  static const int _successNotificationId = 300;

  // Aktif bildirimler listesi
  final Set<int> _activeNotifications = <int>{};

  NotificationService._privateConstructor();

  static Future<void> init() async {
    await instance.initializeNotifications();
  }

  Future<void> initializeNotifications() async {
    try {
      Logger.log('Initializing notifications...');

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      final windowsSettings = WindowsInitializationSettings(
        appName: 'DiscordStorage',
        appUserModelId: 'com.kerem.discordstorage',
        guid: '9c9737b1-1f94-4eaa-8a6b-123456789abc',
      );

      final initializationSettings = InitializationSettings(
        android: androidSettings,
        windows: windowsSettings,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _createNotificationChannels();
      Logger.log('Notifications initialized successfully.');
    } catch (e) {
      Logger.log('Error initializing notifications: $e');
    }
  }

  /// Bildirim kanallarını oluştur
  Future<void> _createNotificationChannels() async {
    // Android için kanalları oluştur
    final channels = [
      AndroidNotificationChannel(
        _fileChannelId,
        'Dosya İşlemleri',
        description: 'Dosya yükleme, indirme ve diğer işlemler',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        _progressChannelId,
        'İlerleme Bildirimleri',
        description: 'İşlem ilerleme durumu',
        importance: Importance.low,
        enableVibration: false,
        playSound: false,
      ),
      AndroidNotificationChannel(
        _errorChannelId,
        'Hata Bildirimleri',
        description: 'Uygulama hataları ve sorunları',
        importance: Importance.high,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        _successChannelId,
        'Başarı Bildirimleri',
        description: 'Başarılı işlem bildirimleri',
        importance: Importance.high,
        enableVibration: false,
      ),
    ];

    for (final channel in channels) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Bildirime tıklanma olayı
  void _onNotificationTap(NotificationResponse response) {
    Logger.log('Notification tapped with payload: ${response.payload}');
    // Burada bildirime özel aksiyonlar eklenebilir
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
        List<AndroidNotificationAction>? actions,
        Duration? timeout,
      }) async {
    try {
      Logger.log('Showing notification: $title - $body');

      final notificationId = id ?? _generateNotificationId();
      final channelInfo = _getChannelInfo(type);

      final androidDetails = AndroidNotificationDetails(
        channelInfo.channelId,
        channelInfo.channelName,
        channelDescription: channelInfo.description,
        importance: _mapPriorityToImportance(priority),
        priority: _mapPriorityToAndroidPriority(priority),
        playSound: playSound,
        actions: actions,
        styleInformation: body.length > 100
            ? BigTextStyleInformation(body, contentTitle: title)
            : null,
        color: _getNotificationColor(type),
        icon: _getNotificationIcon(type),
        ongoing: type == NotificationType.progress,
        autoCancel: type != NotificationType.progress,
        ticker: title,
      );

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: payload,
      );

      _activeNotifications.add(notificationId);
      Logger.log('Notification shown successfully (ID: $notificationId)');

      // Otomatik silme
      if (timeout != null) {
        Future.delayed(timeout, () => cancelNotification(notificationId));
      }

    } catch (e) {
      Logger.log('Error showing notification: $e');
    }
  }

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
      Logger.log('Invalid progress values: $current/$total');
      return;
    }

    try {
      Logger.log('Updating progress notification: $current/$total');

      final notificationId = id ?? _progressNotificationId;
      final progress = (current / total).clamp(0.0, 1.0);
      final progressPercent = (progress * 100).round();

      // Başlık oluştur
      String notificationTitle = title ?? Language.get('operationInProgress');
      if (fileName != null) {
        notificationTitle = '$notificationTitle: $fileName';
      }

      // İçerik oluştur
      String body = _createProgressBody(
        progress: progress,
        current: current,
        total: total,
        progressPercent: progressPercent,
        operation: operation,
        showDetailedProgress: showDetailedProgress,
        barWidth: barWidth,
        showSpeed: showSpeed,
        speed: speed,
        estimatedTime: estimatedTime,
      );

      final androidDetails = AndroidNotificationDetails(
        _progressChannelId,
        'İlerleme Bildirimleri',
        channelDescription: 'Dosya işlemlerinin ilerleme durumu',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: total,
        progress: current,
        ongoing: current < total,
        autoCancel: false,
        styleInformation: showDetailedProgress
            ? BigTextStyleInformation(body, contentTitle: notificationTitle)
            : null,
        actions: current < total ? [
          AndroidNotificationAction(
            'cancel_action',
            'İptal Et',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_cancel'),
          ),
        ] : null,
      );

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        notificationTitle,
        body,
        NotificationDetails(android: androidDetails),
        payload: 'progress_$notificationId',
      );

      _activeNotifications.add(notificationId);

      // İşlem tamamlandıysa
      if (current >= total) {
        await _handleProgressComplete(notificationId, operation, fileName);
      }

    } catch (e) {
      Logger.log('Error showing progress notification: $e');
    }
  }

  /// İlerleme içeriği oluştur
  String _createProgressBody({
    required double progress,
    required int current,
    required int total,
    required int progressPercent,
    String? operation,
    bool showDetailedProgress = true,
    int barWidth = 25,
    bool showSpeed = false,
    double? speed,
    Duration? estimatedTime,
  }) {
    StringBuffer body = StringBuffer();

    if (operation != null) {
      body.writeln(operation);
    }

    if (showDetailedProgress) {
      final progressBar = _createProgressBar(progress, barWidth);
      body.writeln('[$progressBar] $progressPercent%');
    } else {
      body.writeln('$progressPercent%');
    }

    body.writeln('${_formatBytes(current)} / ${_formatBytes(total)}');

    if (showSpeed && speed != null) {
      body.writeln('Hız: ${speed.toStringAsFixed(1)} MB/s');
    }

    if (estimatedTime != null) {
      body.writeln('Kalan süre: ${_formatDuration(estimatedTime)}');
    }

    return body.toString().trim();
  }

  /// İlerleme çubuğu oluştur
  String _createProgressBar(double progress, int width) {
    final pos = (width * progress).round();
    final buffer = StringBuffer();

    for (int i = 0; i < width; i++) {
      if (i < pos) {
        buffer.write('█');
      } else if (i == pos && progress < 1.0) {
        buffer.write('▌');
      } else {
        buffer.write('░');
      }
    }

    return buffer.toString();
  }

  /// İlerleme tamamlandığında çağrılır
  Future<void> _handleProgressComplete(int id, String? operation, String? fileName) async {
    Logger.log('Operation completed, removing progress notification (ID: $id)');

    // İlerleme bildirimini kaldır
    await cancelNotification(id);

    // Başarı bildirimi göster
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
      id: _successNotificationId,
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
      id: _errorNotificationId,
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

  /// Bildirim iptal etme
  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      _activeNotifications.remove(id);
      Logger.log('Notification cancelled (ID: $id)');
    } catch (e) {
      Logger.log('Error cancelling notification: $e');
    }
  }

  /// Tüm bildirimleri iptal et
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      _activeNotifications.clear();
      Logger.log('All notifications cancelled');
    } catch (e) {
      Logger.log('Error cancelling all notifications: $e');
    }
  }

  /// İlerleme bildirimini iptal et
  Future<void> cancelProgressNotification([int? id]) async {
    await cancelNotification(id ?? _progressNotificationId);
  }

  /// Aktif bildirim sayısı
  int get activeNotificationCount => _activeNotifications.length;

  /// Aktif bildirim ID'leri
  Set<int> get activeNotificationIds => Set.from(_activeNotifications);

  // Yardımcı metodlar

  int _generateNotificationId() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  _ChannelInfo _getChannelInfo(NotificationType type) {
    switch (type) {
      case NotificationType.progress:
        return _ChannelInfo(_progressChannelId, 'İlerleme Bildirimleri', 'İşlem ilerleme durumu');
      case NotificationType.error:
        return _ChannelInfo(_errorChannelId, 'Hata Bildirimleri', 'Uygulama hataları');
      case NotificationType.success:
        return _ChannelInfo(_successChannelId, 'Başarı Bildirimleri', 'Başarılı işlemler');
      case NotificationType.warning:
        return _ChannelInfo(_fileChannelId, 'Uyarı Bildirimleri', 'Uyarı mesajları');
      case NotificationType.info:
      return _ChannelInfo(_fileChannelId, 'Dosya İşlemleri', 'Genel bildirimler');
    }
  }

  Color? _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.error:
        return const Color(0xFFD32F2F);
      case NotificationType.success:
        return const Color(0xFF388E3C);
      case NotificationType.warning:
        return const Color(0xFFF57C00);
      case NotificationType.progress:
        return const Color(0xFF1976D2);
      case NotificationType.info:
      return const Color(0xFF7B1FA2);
    }
  }

  String? _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.error:
        return '@drawable/ic_error';
      case NotificationType.success:
        return '@drawable/ic_check';
      case NotificationType.warning:
        return '@drawable/ic_warning';
      case NotificationType.progress:
        return '@drawable/ic_download';
      case NotificationType.info:
      return null;
    }
  }

  Importance _mapPriorityToImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  Priority _mapPriorityToAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }
}

class _ChannelInfo {
  final String channelId;
  final String channelName;
  final String description;

  _ChannelInfo(this.channelId, this.channelName, this.description);
}