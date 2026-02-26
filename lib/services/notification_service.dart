// ============================================================
// SERVICE DE NOTIFICATIONS — COUCHE SERVICE
// Centralise toute la logique liée aux notifications locales.
// Gère les permissions, la planification et les actions
// interactives (Terminer / Reporter) sur Android et iOS.
// ============================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../../domain/entities/task.dart';

/// Identifiants des actions de notification interactives
class NotificationActions {
  static const String complete = 'action_complete';
  static const String snooze = 'action_snooze';

  // Canal de notification principal
  static const String channelId = 'task_reminders';
  static const String channelName = 'Rappels de tâches';
  static const String channelDescription =
      'Notifications de rappel pour vos tâches planifiées';
}

/// Service principal de gestion des notifications locales.
/// À injecter via Riverpod dans les ViewModels qui en ont besoin.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Callback déclenché quand l'utilisateur tape sur une action
  // (défini par le ViewModel qui écoute les interactions)
  void Function(int taskId, String action)? onNotificationAction;

  // ─────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialiser les fuseaux horaires (requis pour les notifs planifiées)
    tz.initializeTimeZones();

    // Paramètres d'initialisation pour Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher', // Icône de la notification
    );

    // Paramètres pour iOS/macOS
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    // Créer les canaux de notification Android (requis Android 8+)
    await _createNotificationChannel();

    _isInitialized = true;
  }

  /// Crée le canal Android avec priorité maximale pour les alarmes
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      NotificationActions.channelId,
      NotificationActions.channelName,
      description: NotificationActions.channelDescription,
      importance: Importance.max,       // Affichage même en "Ne pas déranger"
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: null,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // ─────────────────────────────────────────────────────────
  // DEMANDE DE PERMISSIONS
  // ─────────────────────────────────────────────────────────

  /// Demande les permissions nécessaires selon la plateforme.
  /// Sur Android 13+ (API 33+), la permission POST_NOTIFICATIONS est requise.
  Future<bool> requestPermissions() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      // Demander aussi la permission d'alarmes exactes (Android 12+)
      await androidImpl.requestExactAlarmsPermission();
      return granted ?? false;
    }

    // iOS : les permissions sont demandées à l'initialisation
    return true;
  }

  // ─────────────────────────────────────────────────────────
  // PLANIFICATION DES NOTIFICATIONS
  // ─────────────────────────────────────────────────────────

  /// Planifie une notification pour une tâche à son heure exacte.
  /// La notification inclut deux boutons d'action : Terminer / Reporter.
  Future<void> scheduleTaskNotification(Task task) async {
    if (!_isInitialized) await initialize();
    if (task.id == null) return;

    final scheduledTz = tz.TZDateTime.from(
      task.scheduledDateTime,
      tz.local,
    );

    // Ne planifier que si la date est dans le futur
    if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) return;

    // Actions interactives affichées sur la notification
    final androidActions = <AndroidNotificationAction>[
      const AndroidNotificationAction(
        NotificationActions.complete,
        '✅ Terminer',
        showsUserInterface: false, // Pas besoin d'ouvrir l'appli
        cancelNotification: true,
      ),
      const AndroidNotificationAction(
        NotificationActions.snooze,
        '⏰ Reporter 10 min',
        showsUserInterface: false,
        cancelNotification: false, // On reprogramme manuellement
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      NotificationActions.channelId,
      NotificationActions.channelName,
      channelDescription: NotificationActions.channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,    // Afficher même écran verrouillé
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: false,         // Ne disparaît pas au tap (actions requises)
      actions: androidActions,
      styleInformation: BigTextStyleInformation(
        task.description,
        contentTitle: '🔔 ${task.title}',
        summaryText: 'Tâche planifiée',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      task.id!,
      task.title,
      task.description,
      scheduledTz,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Planifie les notifications répétées toutes les 30 secondes
  /// pendant 10 minutes (20 répétitions) si l'utilisateur n'agit pas.
  Future<void> scheduleRepeatingReminder(Task task) async {
    if (!_isInitialized) await initialize();
    if (task.id == null) return;

    // ID unique pour chaque répétition (taskId * 1000 + index)
    for (int i = 1; i <= 20; i++) {
      final repeatTime = task.scheduledDateTime.add(
        Duration(seconds: 30 * i),
      );

      final scheduledTz = tz.TZDateTime.from(repeatTime, tz.local);
      if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final notifId = task.id! * 1000 + i;

      await _plugin.zonedSchedule(
        notifId,
        '🔁 Rappel : ${task.title}',
        task.description,
        scheduledTz,
        NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationActions.channelId,
            NotificationActions.channelName,
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              const AndroidNotificationAction(
                NotificationActions.complete,
                '✅ Terminer',
                cancelNotification: true,
              ),
              const AndroidNotificationAction(
                NotificationActions.snooze,
                '⏰ Reporter',
                cancelNotification: false,
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Annule toutes les notifications d'une tâche (principal + répétitions)
  Future<void> cancelTaskNotifications(int taskId) async {
    // Annuler la notification principale
    await _plugin.cancel(taskId);

    // Annuler les 20 répétitions
    for (int i = 1; i <= 20; i++) {
      await _plugin.cancel(taskId * 1000 + i);
    }
  }

  /// Affiche une notification immédiate (pour les tests ou confirmations)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationActions.channelId,
          NotificationActions.channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // GESTION DES RÉPONSES AUX NOTIFICATIONS
  // ─────────────────────────────────────────────────────────

  void _onNotificationResponse(NotificationResponse response) {
    final taskId = _extractTaskId(response.id ?? 0);
    final action = response.actionId ?? 'tap';
    onNotificationAction?.call(taskId, action);
  }

  /// Récupère l'id de tâche depuis l'id de notification
  /// (l'id de notification peut être taskId * 1000 + index pour les répétitions)
  int _extractTaskId(int notificationId) {
    if (notificationId > 1000) {
      return notificationId ~/ 1000;
    }
    return notificationId;
  }

  // Annule toutes les notifications planifiées
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

// Handler de fond (doit être une fonction top-level, pas une méthode)
@pragma('vm:entry-point')
void _onBackgroundResponse(NotificationResponse response) {
  // Le workmanager gère les actions en arrière-plan
  // Les données sont transmises via des arguments persistés
}
