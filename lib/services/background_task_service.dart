// ============================================================
// GESTIONNAIRE DE TÂCHES EN ARRIÈRE-PLAN — WORKMANAGER
// Workmanager permet à Flutter d'exécuter du code Dart même
// quand l'application est fermée ou en arrière-plan.
// IMPORTANT : le callbackDispatcher doit être une fonction
// top-level (pas une méthode de classe) car il s'exécute
// dans un isolat Dart séparé.
// ============================================================

import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/datasources/database_helper.dart';
import '../data/models/task_model.dart';
import '../domain/entities/task.dart';

// Noms des tâches Workmanager (identifiants uniques)
class WorkmanagerTasks {
  static const String checkPendingTasks = 'check_pending_tasks';
  static const String scheduleRecurringTask = 'schedule_recurring_task';

  // Fréquence de vérification des tâches en attente (15 min minimum sur Android)
  static const Duration checkInterval = Duration(minutes: 15);
}

/// Point d'entrée du Workmanager — DOIT être top-level.
/// Ce callback est enregistré au démarrage de l'application
/// et s'exécute dans un isolat séparé du thread principal Flutter.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      switch (taskName) {
        case WorkmanagerTasks.checkPendingTasks:
          await _checkAndTriggerPendingTasks();
          break;
        case WorkmanagerTasks.scheduleRecurringTask:
          final taskId = inputData?['taskId'] as int?;
          if (taskId != null) {
            await _rescheduleRecurringTask(taskId);
          }
          break;
      }
      return Future.value(true); // Succès
    } catch (e) {
      print('Erreur Workmanager ($taskName): $e');
      return Future.value(false); // Échec → Workmanager peut retenter
    }
  });
}

/// Vérifie les tâches dont l'heure est proche et déclenche les notifications
Future<void> _checkAndTriggerPendingTasks() async {
  final dbHelper = DatabaseHelper();
  final now = DateTime.now();

  // Fenêtre de vérification : maintenant + 16 min
  // (légèrement supérieure à l'intervalle Workmanager pour éviter les manqués)
  final windowEnd = now.add(const Duration(minutes: 16));

  final rows = await dbHelper.queryByDateRange(
    now.millisecondsSinceEpoch,
    windowEnd.millisecondsSinceEpoch,
  );

  if (rows.isEmpty) return;

  // Initialiser le plugin de notifications (dans l'isolat de fond)
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  for (final row in rows) {
    final task = TaskModel.fromMap(row).toEntity();
    if (task.isCompleted || !task.isActive) continue;

    // Afficher une notification de rappel
    await plugin.show(
      task.id!,
      '🔔 ${task.title}',
      task.description,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Rappels de tâches',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          actions: [
            AndroidNotificationAction('action_complete', '✅ Terminer',
                cancelNotification: true),
            AndroidNotificationAction('action_snooze', '⏰ Reporter',
                cancelNotification: false),
          ],
        ),
      ),
    );
  }
}

/// Reprogramme une tâche récurrente après sa complétion
Future<void> _rescheduleRecurringTask(int taskId) async {
  final dbHelper = DatabaseHelper();
  final row = await dbHelper.queryById(taskId);
  if (row == null) return;

  final task = TaskModel.fromMap(row).toEntity();
  if (!task.isRecurring) return;

  final nextOccurrence = task.calculateNextOccurrence();
  if (nextOccurrence == null) return;

  // Mettre à jour la date dans la base
  await dbHelper.update(
    {
      'scheduled_date_time': nextOccurrence.millisecondsSinceEpoch,
      'is_completed': 0, // Réinitialiser pour la prochaine occurrence
      'next_occurrence': nextOccurrence.millisecondsSinceEpoch,
    },
    taskId,
  );
}

// ─────────────────────────────────────────────────────────
// CLASSE DE CONFIGURATION DU WORKMANAGER
// ─────────────────────────────────────────────────────────

/// Gère l'enregistrement et la configuration du Workmanager.
/// À utiliser depuis le thread principal de l'application.
class BackgroundTaskService {
  /// Initialise Workmanager avec le dispatcher.
  /// À appeler une seule fois dans main().
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // true = logs verbose en développement
    );
  }

  /// Enregistre la tâche de vérification périodique.
  /// S'exécute toutes les 15 minutes (minimum Android).
  static Future<void> registerPeriodicCheck() async {
    await Workmanager().registerPeriodicTask(
      'periodic_task_check',          // ID unique persistant
      WorkmanagerTasks.checkPendingTasks,
      frequency: WorkmanagerTasks.checkInterval,
      constraints: Constraints(
        networkType: NetworkType.not_required, // Pas besoin du réseau
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Annule toutes les tâches Workmanager enregistrées
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
