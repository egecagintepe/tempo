import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.local);
      } catch (_) {}
    }

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

  // --- IMMEDIATE NOTIFICATIONS ---
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

  // --- SCHEDULED NOTIFICATIONS (Alarms for Background & Sleep) ---
  Future<void> scheduleTimerCompletedNotification({
    required String categoryName,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

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

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        2001,
        'Oturum Tamamlandı! — $categoryName',
        'Hedef odak sürene ulaşıldı. Oturumunu tamamlayabilirsin.',
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        // Fallback to inexact if exact alarm permission is denied
        await _notificationsPlugin.zonedSchedule(
          2001,
          'Oturum Tamamlandı! — $categoryName',
          'Hedef odak sürene ulaşıldı. Oturumunu tamamlayabilirsin.',
          tzDateTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  Future<void> scheduleBreakCompletedNotification({
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

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

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        2002,
        'Mola Bitti!',
        'Zihnini dinlendirdin. Odaklanmaya devam etmeye hazır mısın?',
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          2002,
          'Mola Bitti!',
          'Zihnini dinlendirdin. Odaklanmaya devam etmeye hazır mısın?',
          tzDateTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  Future<void> scheduleBudgetWarningNotification({
    required String categoryName,
    required int percent,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'tempo_budget_channel',
      'TEMPO Bütçe Uyarıları',
      channelDescription: 'Kategori bütçe sınır uyarıları',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        2010 + percent,
        'Bütçe Uyarısı: %$percent — $categoryName',
        '$categoryName için haftalık bütçenin %$percent\'i kullanıldı.',
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelScheduledTimerNotifications() async {
    try {
      await _notificationsPlugin.cancel(2001);
      await _notificationsPlugin.cancel(2002);
      await _notificationsPlugin.cancel(2080);
      await _notificationsPlugin.cancel(2095);
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }
}
