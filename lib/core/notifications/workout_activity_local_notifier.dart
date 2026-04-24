import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Aviso no sistema (ex.: ecrã bloqueado) quando o aluno atualiza o treino e o
/// app do personal não está em primeiro plano.
class WorkoutActivityLocalNotifier {
  WorkoutActivityLocalNotifier._();

  static final WorkoutActivityLocalNotifier instance =
      WorkoutActivityLocalNotifier._();

  static const int _notificationId = 0x776f7274; // "wort" — id estável
  static const int _restTimerNotificationId = 0x72657374; // "rest"

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneInitialized = false;

  Future<void> _ensureTimezoneInitialized() async {
    if (_timezoneInitialized) return;
    tz_data.initializeTimeZones();
    _timezoneInitialized = true;
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<void> showUpdate({required String title, required String body}) async {
    if (kIsWeb || !_initialized) return;

    final android = AndroidNotificationDetails(
      'workout_activity',
      'Atividade dos alunos',
      channelDescription:
          'Avisos quando alunos iniciam, registam séries ou concluem treinos.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
  }

  Future<void> scheduleRestTimerEnd({
    required DateTime at,
    String title = 'Descanso finalizado',
    String body = 'Hora de registrar a próxima série.',
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();
    if (!_initialized) return;
    await _ensureTimezoneInitialized();

    final when = at.isAfter(DateTime.now())
        ? at
        : DateTime.now().add(const Duration(seconds: 1));

    final android = AndroidNotificationDetails(
      'rest_timer_end',
      'Timer de descanso',
      channelDescription:
          'Avisos sonoros ao final do intervalo entre séries, inclusive com a tela bloqueada.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.zonedSchedule(
      id: _restTimerNotificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelRestTimerEnd() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(id: _restTimerNotificationId);
  }
}
