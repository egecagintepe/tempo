import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback if platform not supported
    }
  }

  Future<void> requestPermissions() async {
    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  Future<void> showTimerCompletedNotification({
    required String categoryName,
    required String durationText,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'tempo_timer_channel',
      'TEMPO Odak Sayacı',
      channelDescription: 'Oturum ve mola bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        1001,
        'Oturum Tamamlandı! — $categoryName',
        '$durationText boyunca odaklandın. Harika iş çıkardın!',
        details,
      );
    } catch (_) {}
  }

  Future<void> showBreakCompletedNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'tempo_timer_channel',
      'TEMPO Odak Sayacı',
      channelDescription: 'Oturum ve mola bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        1002,
        'Mola Bitti!',
        'Zihnini dinlendirdin. Yeni bir odak oturumuna hazır mısın?',
        details,
      );
    } catch (_) {}
  }

  Future<void> showBudgetWarningNotification({
    required String categoryName,
    required int percent,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'tempo_budget_channel',
      'TEMPO Bütçe Uyarıları',
      channelDescription: 'Kategori bütçe sınır uyarıları',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        1003 + percent,
        'Bütçe Uyarısı: %$percent — $categoryName',
        '$categoryName için haftalık bütçenin %$percent\'i kullanıldı.',
        details,
      );
    } catch (_) {}
  }
}
