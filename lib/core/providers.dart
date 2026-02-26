// ============================================================
// PROVIDERS RIVERPOD — INJECTION DE DÉPENDANCES & STATE
// Ce fichier est le "cœur" de l'architecture Riverpod.
// Il déclare tous les providers qui injectent les services,
// repositories et use cases dans l'application.
//
// Principe Riverpod : chaque provider est global, lazy
// (créé au premier accès) et automatiquement disposé
// quand plus personne ne l'écoute.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/database_helper.dart';
import '../data/repositories/task_repository_impl.dart';
import '../domain/entities/task.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/usecases/task_usecases.dart';
import '../services/ai_service.dart';
import '../services/audio_service.dart';
import '../services/background_task_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/speech_service.dart';

// ─────────────────────────────────────────────────────────
// COUCHE DATA — PROVIDERS D'INFRASTRUCTURE
// ─────────────────────────────────────────────────────────

/// Provider du helper SQLite (singleton)
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// Provider du repository (implémentation concrète)
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final repo = TaskRepositoryImpl(dbHelper: dbHelper);
  // Dispose automatique quand le provider est libéré
  ref.onDispose(() => repo.dispose());
  return repo;
});

// ─────────────────────────────────────────────────────────
// COUCHE DOMAIN — PROVIDERS DES USE CASES
// ─────────────────────────────────────────────────────────

final getAllTasksUseCaseProvider = Provider<GetAllTasksUseCase>((ref) {
  return GetAllTasksUseCase(ref.watch(taskRepositoryProvider));
});

final getTodayTasksUseCaseProvider = Provider<GetTodayTasksUseCase>((ref) {
  return GetTodayTasksUseCase(ref.watch(taskRepositoryProvider));
});

final getTomorrowTasksUseCaseProvider = Provider<GetTomorrowTasksUseCase>((ref) {
  return GetTomorrowTasksUseCase(ref.watch(taskRepositoryProvider));
});

final createTaskUseCaseProvider = Provider<CreateTaskUseCase>((ref) {
  return CreateTaskUseCase(ref.watch(taskRepositoryProvider));
});

final updateTaskUseCaseProvider = Provider<UpdateTaskUseCase>((ref) {
  return UpdateTaskUseCase(ref.watch(taskRepositoryProvider));
});

final deleteTaskUseCaseProvider = Provider<DeleteTaskUseCase>((ref) {
  return DeleteTaskUseCase(ref.watch(taskRepositoryProvider));
});

final completeTaskUseCaseProvider = Provider<CompleteTaskUseCase>((ref) {
  return CompleteTaskUseCase(ref.watch(taskRepositoryProvider));
});

final snoozeTaskUseCaseProvider = Provider<SnoozeTaskUseCase>((ref) {
  return SnoozeTaskUseCase(ref.watch(taskRepositoryProvider));
});

// ─────────────────────────────────────────────────────────
// COUCHE SERVICE — PROVIDERS DES SERVICES TECHNIQUES
// ─────────────────────────────────────────────────────────

/// Service de notifications (initialisé une fois)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize(); // Init asynchrone non bloquante
  return service;
});

/// Service audio & TTS
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Service de reconnaissance vocale
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService();
  service.initialize();
  return service;
});

/// Service IA (OpenAI/Gemini)
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

/// Service de permissions
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

// ─────────────────────────────────────────────────────────
// ÉTATS RÉACTIFS — PROVIDERS DE DONNÉES
// Ces providers exposent les données de manière réactive.
// L'UI se reconstruit automatiquement quand les données changent.
// ─────────────────────────────────────────────────────────

/// Stream de toutes les tâches (mise à jour en temps réel)
final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchAllTasks();
});

/// Tâches du jour (recalculées à chaque changement de la liste globale)
final todayTasksProvider = FutureProvider<List<Task>>((ref) {
  return ref.watch(getTodayTasksUseCaseProvider).call();
});

/// Tâches de demain
final tomorrowTasksProvider = FutureProvider<List<Task>>((ref) {
  return ref.watch(getTomorrowTasksUseCaseProvider).call();
});

/// Toutes les tâches
final allTasksProvider = FutureProvider<List<Task>>((ref) {
  return ref.watch(getAllTasksUseCaseProvider).call();
});

// ─────────────────────────────────────────────────────────
// ÉTAT D'UNE TÂCHE EN COURS DE RAPPEL
// ─────────────────────────────────────────────────────────

/// Tâche actuellement en train de sonner (null si aucune)
final activeReminderProvider = StateProvider<Task?>((ref) => null);

/// Indique si la reconnaissance vocale est active
final isListeningProvider = StateProvider<bool>((ref) => false);

/// Texte partiel reconnu (pour l'indicateur visuel)
final partialSpeechResultProvider = StateProvider<String>((ref) => '');

/// Réponse IA en cours de chargement
final aiLoadingProvider = StateProvider<bool>((ref) => false);

/// Dernière réponse de l'IA
final aiResponseProvider = StateProvider<AiResponse?>((ref) => null);
