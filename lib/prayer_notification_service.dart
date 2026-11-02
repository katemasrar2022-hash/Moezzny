
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationSettings {
  final bool adhanEnabled;
  final bool iqamaEnabled;
  final int iqamaMinutes;

  const PrayerNotificationSettings({
    this.adhanEnabled = false,
    this.iqamaEnabled = false,
    this.iqamaMinutes = 15,
  });

  PrayerNotificationSettings copyWith({
    bool? adhanEnabled,
    bool? iqamaEnabled,
    int? iqamaMinutes,
  }) {
    return PrayerNotificationSettings(
      adhanEnabled: adhanEnabled ?? this.adhanEnabled,
      iqamaEnabled: iqamaEnabled ?? this.iqamaEnabled,
      iqamaMinutes: iqamaMinutes ?? this.iqamaMinutes,
    );
  }
}

class PrayerNotificationService {
  PrayerNotificationService._();

  static final PrayerNotificationService instance =
      PrayerNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _settingsPrefix = 'moezzny_prayer_settings_v1_';

  static const List<String> prayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  static const Map<String, String> prayerNames = {
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  static const Map<String, int> defaultIqamaMinutes = {
    'fajr': 20,
    'dhuhr': 15,
    'asr': 15,
    'maghrib': 5,
    'isha': 15,
  };

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(
      tz.getLocation(timezoneInfo.identifier),
    );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );

    _initialized = true;
  }

  Future<PrayerNotificationSettings> loadSettings(
    String prayerKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_settingsPrefix$prayerKey';

    return PrayerNotificationSettings(
      adhanEnabled: prefs.getBool('${key}_adhan') ?? false,
      iqamaEnabled: prefs.getBool('${key}_iqama') ?? false,
      iqamaMinutes: prefs.getInt('${key}_minutes') ??
          defaultIqamaMinutes[prayerKey] ??
          15,
    );
  }

  Future<void> saveSettings(
    String prayerKey,
    PrayerNotificationSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_settingsPrefix$prayerKey';

    await prefs.setBool(
      '${key}_adhan',
      settings.adhanEnabled,
    );

    await prefs.setBool(
      '${key}_iqama',
      settings.iqamaEnabled,
    );

    await prefs.setInt(
      '${key}_minutes',
      settings.iqamaMinutes,
    );
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return true;

    final granted =
        await android.requestNotificationsPermission();

    return granted ?? true;
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return true;

    try {
      final granted = await android.requestExactAlarmsPermission();
      return granted ?? false;
    } catch (error) {
      debugPrint('MOEZZNY EXACT ALARM PERMISSION: $error');
      return false;
    }
  }

  int _adhanId(String prayerKey, DateTime date) {
    final index = prayerKeys.indexOf(prayerKey);
    final day = date.year * 10000 + date.month * 100 + date.day;
    return day * 10 + index * 2 + 1;
  }

  int _iqamaId(String prayerKey, DateTime date) {
    return _adhanId(prayerKey, date) + 1;
  }

  Future<void> cancelPrayerNotifications() async {
    await initialize();

    for (final prayer in prayerKeys) {
      for (var dayOffset = -1; dayOffset <= 3; dayOffset++) {
        final date = DateTime.now().add(
          Duration(days: dayOffset),
        );

        await _plugin.cancel(
          id: _adhanId(prayer, date),
        );

        await _plugin.cancel(
          id: _iqamaId(prayer, date),
        );
      }
    }
  }

  Future<void> schedulePrayerNotifications({
    required Map<String, DateTime> prayerTimes,
  }) async {
    await initialize();

    final now = DateTime.now();

    for (final prayerKey in prayerKeys) {
      final prayerTime = prayerTimes[prayerKey];
      if (prayerTime == null) continue;

      final settings = await loadSettings(prayerKey);

      final adhanId = _adhanId(prayerKey, prayerTime);
      final iqamaId = _iqamaId(prayerKey, prayerTime);

      await _plugin.cancel(id: adhanId);
      await _plugin.cancel(id: iqamaId);

      if (settings.adhanEnabled && prayerTime.isAfter(now)) {
        await _schedule(
          id: adhanId,
          title: 'حان وقت صلاة ${prayerNames[prayerKey]}',
          body: 'حي على الصلاة',
          time: prayerTime,
        );
      }

      if (settings.iqamaEnabled) {
        final iqamaTime = prayerTime.add(
          Duration(minutes: settings.iqamaMinutes),
        );

        if (iqamaTime.isAfter(now)) {
          await _schedule(
            id: iqamaId,
            title: 'موعد إقامة صلاة ${prayerNames[prayerKey]}',
            body: 'حان وقت الإقامة',
            time: iqamaTime,
          );
        }
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime time,
  }) async {
    final scheduledDate = tz.TZDateTime.from(
      time,
      tz.local,
    );

    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'moezzny_prayer_notifications',
        'تنبيهات الصلاة والإقامة',
        channelDescription: 'تنبيهات مواقيت الصلاة والإقامة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('MOEZZNY EXACT SCHEDULE ERROR: $error');

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode:
            AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

