import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Notification IDs (never reuse across types) ───────────────────────────
  static const int _idDailyBonusMorning = 1;
  static const int _idDailyBonusEvening = 2;
  static const int _idLifeRegen         = 3;
  static const int _idComeBack          = 4;
  static const int _idFlashSale         = 5;
  static const int _idStreakReminder     = 6;

  // ─── Android channel ──────────────────────────────────────────────────────
  static const String _channelId   = 'crystal_cascade_main';
  static const String _channelName = 'Crystal Cascade';
  static const String _channelDesc = 'Bonus, reminder and sale notifications';

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    // Timezone data must be loaded first
    tzdata.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Request Android 13+ runtime permission
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    // Notifications use inexact scheduling (see zonedSchedule calls below),
    // so no exact-alarm permission or extra runtime request is needed.

    _initialized = true;

    // Schedule standing daily notifications on first init
    await scheduleDailyBonus();
    await scheduleStreakReminder();
  }

  void _onTap(NotificationResponse response) {
    // Notification tap handler — add deep-link routing here if needed
    debugPrint('Notification tapped: ${response.id} payload=${response.payload}');
  }

  // ─── Notification details helpers ─────────────────────────────────────────
  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableLights: true,
        color: Color(0xFF533483),
        playSound: true,
        enableVibration: true,
      );

  NotificationDetails get _details => NotificationDetails(
        android: _androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  // ─── Daily Bonus (repeating, morning + evening) ───────────────────────────
  Future<void> scheduleDailyBonus() async {
    await _plugin.zonedSchedule(
      _idDailyBonusMorning,
      '🎁 Daily Bonus Ready!',
      'Claim your 50 free coins — they\'re waiting for you!',
      _nextTimeOfDay(10, 0),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _plugin.zonedSchedule(
      _idDailyBonusEvening,
      '💎 Evening Bonus Waiting!',
      'Don\'t let your daily coins go to waste. Tap to collect!',
      _nextTimeOfDay(19, 0),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── Streak Reminder (8 AM daily) ─────────────────────────────────────────
  Future<void> scheduleStreakReminder() async {
    await _plugin.zonedSchedule(
      _idStreakReminder,
      '🔥 Keep Your Streak Alive!',
      'One level a day keeps the streak going. Play Crystal Cascade!',
      _nextTimeOfDay(8, 0),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── Life Regen (fires when all used lives are restored) ──────────────────
  //  Called every time a life is consumed.
  //  missingLives: how many lives below max (each costs 30 min).
  Future<void> scheduleLifeRegen(int missingLives) async {
    if (missingLives <= 0) return;

    await _plugin.cancel(_idLifeRegen); // reset the timer

    final regenDuration = Duration(minutes: missingLives * 30);
    final fireAt =
        tz.TZDateTime.now(tz.local).add(regenDuration);

    await _plugin.zonedSchedule(
      _idLifeRegen,
      '❤️ Lives Refilled!',
      'All your lives are back. Come jump into Crystal Cascade!',
      fireAt,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelLifeRegen() async =>
      await _plugin.cancel(_idLifeRegen);

  // ─── Come-Back Reminder (2 h after going to background) ──────────────────
  Future<void> scheduleComeBackReminder() async {
    await _plugin.cancel(_idComeBack);

    final fireAt =
        tz.TZDateTime.now(tz.local).add(const Duration(hours: 2));

    await _plugin.zonedSchedule(
      _idComeBack,
      '💎 Crystal Cascade Misses You!',
      'Your crystals are waiting. Come back and sort some gems!',
      fireAt,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Flash Sale (3 h after going to background) ───────────────────────────
  //  Urgency-driven monetization push.
  Future<void> scheduleFlashSale() async {
    await _plugin.cancel(_idFlashSale);

    final fireAt =
        tz.TZDateTime.now(tz.local).add(const Duration(hours: 3));

    await _plugin.zonedSchedule(
      _idFlashSale,
      '⚡ FLASH SALE — Limited Time!',
      'Remove Ads for just \$0.99 today only. Grab it before it\'s gone!',
      fireAt,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Called when app goes to background ───────────────────────────────────
  Future<void> onAppBackground({required int missingLives}) async {
    await scheduleComeBackReminder();
    await scheduleFlashSale();
    if (missingLives > 0) await scheduleLifeRegen(missingLives);
  }

  // ─── Called when app comes to foreground ──────────────────────────────────
  Future<void> onAppForeground() async {
    await _plugin.cancel(_idComeBack);
    await _plugin.cancel(_idFlashSale);
  }

  // ─── Utility ──────────────────────────────────────────────────────────────
  tz.TZDateTime _nextTimeOfDay(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var target =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  Future<void> cancelAll() async => await _plugin.cancelAll();
}
